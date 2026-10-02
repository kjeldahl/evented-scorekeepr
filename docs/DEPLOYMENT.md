# Deployment

Scorekeepr deploys with [Kamal](https://kamal-deploy.org) to a single
Hetzner server. The configuration lives in `config/deploy.yml`; this
document is the operational walkthrough - provisioning, secrets, first
deploy, and backup/restore of the event store.

## Topology

One Hetzner server runs three containers on Kamal's shared docker network:

| Container        | Role                                                        |
|------------------|-------------------------------------------------------------|
| `scorekeepr-web` | Rails app behind kamal-proxy (TLS via Let's Encrypt)        |
| `scorekeepr-db`  | PostgreSQL 16 - the DCB event store, the only persistence   |
| `scorekeepr-db-backup` | Nightly `pg_dump` with rotation                       |

PostgreSQL is reached by container name (`scorekeepr-db`) over the docker
network and is **not** published on any host port.

The app must stay a **single Puma process** (`WEB_CONCURRENCY: 1`):
ActionCable uses the in-process `async` adapter (`config/cable.yml`).
Switch cable to the `redis` adapter before scaling to multiple processes
or servers.

## Provisioning the Hetzner server

1. Create a server (Ubuntu 24.04, x86 - for ARM/CAX change
   `builder.arch` to `arm64` in `config/deploy.yml`).
2. Add your SSH key during creation; Kamal connects as `root` by default.
3. Point your domain's DNS A record at the server IP. kamal-proxy will
   obtain the Let's Encrypt certificate automatically on first deploy.
4. Optional but recommended: a Hetzner Cloud Firewall allowing only
   22, 80 and 443 inbound. Docker is installed by `kamal setup` if missing.

Then fill in the `TODO` markers in `config/deploy.yml`: server IP (three
places), `proxy.host`, registry username/image.

## Secrets

`.kamal/secrets` is committed and contains only *references*; values come
from the deploying user's environment:

```bash
export KAMAL_REGISTRY_PASSWORD=...   # registry token (ghcr.io: PAT with write:packages)
export POSTGRES_PASSWORD=...         # invent once, keep in your password manager
```

`RAILS_MASTER_KEY` is read from `config/master.key` (gitignored - get it
from a teammate or your password manager). `POSTGRES_PASSWORD` initialises
the database accessory and is handed to the app as `EVENT_STORE_PASSWORD`
(see `config/event_store.yml`).

## First deploy and day-to-day commands

```bash
bin/kamal setup        # first time: installs Docker, boots accessories, deploys
bin/kamal deploy       # subsequent deploys
bin/kamal console      # Rails console on the server
bin/kamal logs         # tail app logs
bin/kamal shell        # bash in the app container
bin/kamal accessory logs db-backup   # check backup runs
```

The app container's entrypoint runs `bin/rails event_store:prepare` on
boot (idempotent: creates the database, events table and supporting
functions if missing) - the no-ActiveRecord equivalent of `db:prepare`.

## Continuous deployment (GitHub Actions)

`.github/workflows/deploy.yml` runs `bin/kamal deploy` after CI passes on a
push to `main` (skipped if `main` has since moved on), or on demand via
*Actions → Deploy → Run workflow*. It replaces `.kamal/secrets` on the runner
with values from GitHub secrets, so 1Password isn't needed there.

One-time setup:

1. Repo secrets (Settings → Secrets and variables → Actions, or on the
   `production` environment):
   - `SSH_PRIVATE_KEY` - a deploy key whose public half is in the server's
     `/root/.ssh/authorized_keys`
   - `RAILS_MASTER_KEY` - contents of `config/master.key`
   - `POSTGRES_PASSWORD` - same value as in 1Password
2. Registry auth uses the workflow's `GITHUB_TOKEN`. If the
   `ghcr.io/kjeldahl/scorekeepr` package was first pushed with a PAT, grant
   this repo write access under the package's *Manage Actions access*.

## Backups

The `db-backup` accessory ([prodrigestivill/postgres-backup-local](https://github.com/prodrigestivill/docker-postgres-backup-local))
runs `pg_dump` daily at 02:00 UTC and rotates: 7 daily, 4 weekly,
6 monthly dumps. Dumps land on the host under
`~/scorekeepr-db-backup/backups/` (the PostgreSQL data directory itself is
bind-mounted at `~/scorekeepr-db/data/`).

Trigger an immediate backup (e.g. before a risky migration):

```bash
ssh root@<server-ip> "docker exec scorekeepr-db-backup /backup.sh"
```

### Restore

```bash
# 1. Stop the app so nothing writes to the event store mid-restore.
bin/kamal app stop

# 2. On the server, restore the chosen dump into a fresh database.
ssh root@<server-ip>
zcat ~/scorekeepr-db-backup/backups/daily/scorekeepr_production-<date>.sql.gz | \
  docker exec -i scorekeepr-db psql -U scorekeepr -d postgres \
    -c "DROP DATABASE scorekeepr_production;" \
    -c "CREATE DATABASE scorekeepr_production OWNER scorekeepr;"
zcat ~/scorekeepr-db-backup/backups/daily/scorekeepr_production-<date>.sql.gz | \
  docker exec -i scorekeepr-db psql -U scorekeepr scorekeepr_production

# 3. Restart the app.
bin/kamal app boot
```

Because the events table is append-only and every projection is derived
from it, restoring the dump restores the complete application state -
there are no other databases, caches or file stores to reconcile.

### Off-site copies

The dumps above live on the same server as the database, which protects
against bad deploys and `DROP TABLE`, not against losing the server. Two
cheap options on Hetzner:

- **Hetzner server backups** (the checkbox on the server, 20% of the
  server price): whole-disk snapshots, zero setup. Good baseline.
- **Hetzner Storage Box**: sync the dump directory off the machine, e.g.
  a root cron entry on the server:

  ```cron
  30 3 * * * rsync -a --delete -e "ssh -p23" /root/scorekeepr-db-backup/backups/ u123456@u123456.your-storagebox.de:scorekeepr-backups/
  ```

Periodically test a restore against a scratch database - a backup that
has never been restored is a hope, not a backup.
