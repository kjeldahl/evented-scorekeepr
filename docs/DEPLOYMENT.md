# Deployment

Scorekeepr ships as a Docker image (`Dockerfile`) and deploys with
[Kamal](https://kamal-deploy.org). The production deployment of this repo
lives in a private repo; this document covers what you need to self-host.

## Self-hosting

### Topology

One server runs three containers on Kamal's shared docker network:

| Container | Role |
|---|---|
| `<service>-web` | Rails app behind kamal-proxy (TLS via Let's Encrypt) |
| `<service>-db` | PostgreSQL 16 (>= 13) - the DCB event store, the only persistence |
| `<service>-db-backup` | Optional: scheduled `pg_dump` with rotation |

Keep PostgreSQL on the docker network only (reach it by container name);
don't publish it on a host port.

The app must stay a **single Puma process** (`WEB_CONCURRENCY: 1`):
ActionCable uses the in-process `async` adapter (`config/cable.yml`).
Switch cable to the `redis` adapter before scaling to multiple processes
or servers.

### Kamal config

Install Kamal (`gem install kamal`) and create `config/deploy.yml` (and
`.kamal/secrets`) in your checkout. Both are ignored by the Docker build
(`.dockerignore`). A minimal starting point:

```yaml
service: scorekeepr
image: <registry-user>/scorekeepr

servers:
  web:
    - <server-ip>

proxy:
  ssl: true
  host: <your-domain>

registry:
  server: ghcr.io
  username: <registry-user>
  password:
    - KAMAL_REGISTRY_PASSWORD

builder:
  arch: amd64

env:
  clear:
    EVENT_STORE_HOST: scorekeepr-db
    EVENT_STORE_PORT: 5432
    EVENT_STORE_USER: scorekeepr
    EVENT_STORE_DATABASE: scorekeepr_production
    WEB_CONCURRENCY: 1
    APP_HOST: <your-domain>
    SMTP_ADDRESS: <smtp-host>
    SMTP_PORT: 587
    MAIL_FROM: "Scorekeepr <noreply@<your-domain>>"
  secret:
    - RAILS_MASTER_KEY
    - EVENT_STORE_PASSWORD
    - SMTP_USERNAME
    - SMTP_PASSWORD

accessories:
  db:
    image: postgres:16
    host: <server-ip>
    env:
      clear:
        POSTGRES_USER: scorekeepr
        POSTGRES_DB: scorekeepr_production
      secret:
        - POSTGRES_PASSWORD
    directories:
      - data:/var/lib/postgresql/data
```

### Environment

| Variable | Kind | Purpose |
|---|---|---|
| `RAILS_MASTER_KEY` | secret | Decrypts `config/credentials.yml.enc` (use your own credentials file and key) |
| `EVENT_STORE_HOST`, `_PORT`, `_USER`, `_DATABASE` | clear | Event store connection (`config/event_store.yml`) |
| `EVENT_STORE_PASSWORD` | secret | Same value as the db accessory's `POSTGRES_PASSWORD` |
| `APP_HOST` | clear | Host for links in emails |
| `SMTP_ADDRESS`, `SMTP_PORT` | clear | SMTP relay (submission port 587 + STARTTLS) |
| `SMTP_USERNAME`, `SMTP_PASSWORD` | secret | SMTP credentials |
| `MAIL_FROM` | clear | Default sender address |
| `APPSIGNAL_PUSH_API_KEY` | secret, optional | AppSignal monitoring |

Many cloud providers block outbound ports 25/465; use a relay on 587.

### Deploy

```bash
kamal setup     # first time: installs Docker, boots accessories, deploys
kamal deploy    # subsequent deploys
kamal console   # Rails console (add the alias, or: kamal app exec -i "bin/rails console")
```

The app container's entrypoint runs `bin/rails event_store:prepare` on
boot (idempotent: creates the database, events table and supporting
functions if missing) - the no-ActiveRecord equivalent of `db:prepare`. It
also upgrades an existing schema in place when the `dcb_event_store` gem
adds to it, so a gem bump needs no manual migration, and older app
containers keep working against the upgraded schema (`kamal rollback`
stays safe).

### Backups and restore

Because the events table is append-only and every projection is derived
from it, a `pg_dump` of the event store database is a complete backup of
the application state. Restoring one:

1. `kamal app stop`
2. Recreate the database and load the dump into it (`psql` inside the db
   container).
3. `kamal app boot`. Its `event_store:prepare` must run before the first
   append on a restored dump (it moves new transaction ids past the
   restored rows' `tx_id`).
