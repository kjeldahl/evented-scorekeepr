# Scorekeepr

A SaaS for keeping score in office and family tournaments and leagues —
foosball, table tennis, or any game you can put a number on. Fully event
sourced on the [Dynamic Consistency Boundary](https://dcb.events) pattern
using [Kjeldahl/ruby-dcb](https://github.com/Kjeldahl/ruby-dcb): the
append-only `events` table is the only persistence in the system. There is
no ActiveRecord.

## What it does

- **Accounts** are tenants (an office, a family). Players register once and
  can be invited into any number of accounts by email.
- **Leagues** live in an account, one game type each (an account can run
  many leagues at once, even for the same game). A league runs until someone
  closes it — the end date need not be known up front.
- **Matches** are registered through a one-screen form built for speed:
  pick the players (1v1 or two-on-two), type the score (21–8), done.
- **Scoring** is a zero-sum stake model: each losing player stakes a
  percentage (league-configurable, default 10%) of their current points
  and the pot goes to the winners. Everyone starts at the league's
  starting points (default 1000).
- **Scoreboards** show ranked standings with points, played/won/lost,
  win %, points for/against and current streak, plus the latest results.

The full domain rules live in [docs/DOMAIN.md](docs/DOMAIN.md); the
architecture and slice conventions in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Architecture in one paragraph

The app is built in vertical slices (`app/slices/{identity,accounts,leagues,
matches,scoreboards}`), each with pure-Ruby domain code (`domain/`), thin
controllers (`web/`) and templates (`views/`). Slices never reference each
other's classes — events are the only integration contract. Commands build
a DCB decision model (projections folded from the store), validate
invariants against the folded state, and append with the model's append
condition, so every invariant (unique email, accept-an-invitation-once,
no-matches-in-closed-leagues, …) is race-safe without locks on read models.
Read models, including the scoreboard, are folds over events.

## Getting started

Requirements: Ruby >= 4.0, a running PostgreSQL server.

In Claude Code cloud sessions, `.claude/hooks/session-start.sh` installs the
prebuilt Ruby from `.ruby-version` via mise plus the gems (skipping the
`development`, `deploy` and `production` groups). The environment's network
allowlist needs `mise-versions.jdx.dev` and `tuf-repo-cdn.sigstore.dev`.

```bash
bin/setup
```

That installs the gems, creates the `scorekeepr` PostgreSQL role and the
development and test databases with the event store schema (idempotent —
safe to re-run any time), and starts the server. Pass `--skip-server` to
set up without starting it. If the script cannot reach PostgreSQL as a
superuser it prints the `CREATE ROLE` statement to run manually; the
individual steps are also available as `bin/rails event_store:prepare`
(database + schema) and `bin/rails event_store:setup` (schema only).

Connection settings can be overridden with `EVENT_STORE_HOST/PORT/USER/
PASSWORD/DATABASE` (see `config/event_store.yml`).

## Tests and quality gates

Behaviour is specified in Gherkin (`features/**/*.feature`) and executed
with Cucumber; domain code is unit tested with RSpec. Tests run against the
gem's in-memory event store by default (fast, parallel-safe); set
`EVENT_STORE_ADAPTER=postgres` to exercise the real PostgreSQL-backed store
(CI runs both).

```bash
bundle exec rspec        # unit specs
bundle exec cucumber     # executable feature specs
bin/rails quality:crap   # crap4r: CRAP score <= 8 for every method
bin/rails quality:mutant # mutation testing of slice domain code
bin/rails quality        # all of the above
```

Quality tooling:

- [Kjeldahl/crap4r](https://github.com/Kjeldahl/crap4r) keeps every method
  at a CRAP score of 8 or below (complexity² × untested³ + complexity).
- [mutant](https://github.com/mbj/mutant) mutation-tests the slice domain
  code to prove the specs actually pin the behaviour. CI runs it
  incrementally (`--since` the base revision, only subjects you touched);
  a scheduled workflow runs the full suite weekly when anything changed.
- SimpleCov (`config/coverage.rb`) merges the RSpec and Cucumber runs into
  one `coverage/` report. CI (postgres leg) posts a sticky PR comment with
  the coverage delta against the base branch (`script/coverage_report.rb`);
  pushes to `main` publish the HTML report and a coverage-over-time chart
  to GitHub Pages (`.github/workflows/pages.yml`).

## Development roles

The repository defines four agent roles under `.claude/agents/` used to
build and evolve the system: **specifier** (owns the Gherkin features),
**coder** (implements slices to make them pass), **refactorer** (keeps
CRAP scores low and mutants dead) and **architect** (guards slice
boundaries and the event-sourcing rules).
