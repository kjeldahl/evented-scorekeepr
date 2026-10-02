# Scorekeepr — project rules

Ruby (see `.ruby-version`), Rails 8.1. Event-sourced SaaS for game leagues.
**No ActiveRecord**: the only persistence is the append-only `events` table of
the DCB event store (github.com/Kjeldahl/ruby-dcb).

## Canonical documentation (read before changing anything)
- `docs/DOMAIN.md`: domain rules, scoring model, event catalogue. **Normative.**
  Never contradict it.
- `docs/ARCHITECTURE.md`: slice conventions, routing table, hard constraints.
  Routing table and `config/routes.rb` must stay in sync.
- `docs/REVIEW.md`: "adding a new slice" checklist.

## Hard constraints
- Vertical slices under `app/slices/<slice>/{domain,web,views}`. Slices never
  reference each other's classes. **Events are the only cross-slice contract**
  (sole exception: `ApplicationController` → `Identity::Users.find`). Shared UI
  lives only in `app/views/layouts` and `app/controllers/application_controller.rb`.
- Events are immutable past-tense facts. Invariants enforced via DCB append
  conditions: every command append carries its decision model's append
  condition when an invariant depends on what was read; failed validation never
  writes. No read-then-write without a condition. Read models are projections
  with no hidden state outside the event store.
- Dependency direction: web → domain → EventStore. Controllers hold no domain logic.
- Rejection messages in commands match the feature files verbatim.

## Environment
- If gems are missing, run `bundle install`. If the gem bindir is missing from
  PATH, prepend the active Ruby's bindir (rbenv/mise) when running `bundle exec ...`.
- Tests default to the in-memory event store (parallel-safe). Postgres only for
  the dev server and the integration path
  (`EVENT_STORE_ADAPTER=postgres bundle exec rspec/cucumber`).
- Demo data: `bin/rails demo:seed` (or `demo:populate`).

## Acceptance
- Acceptance is **Cucumber**: `features/**/*.feature`, step definitions per slice
  in `features/step_definitions/<slice>_steps.rb`. Run via `bin/rails quality:features`.
- No Gherkin acceptance mutation; do not install APS `gherkin-parser`/`gherkin-mutator`.
- `.feature` files are owned by the specifier role only (see `.claude/agents/`).

## Quality gates (all must stay green)
| Task | Tool | Bar |
|---|---|---|
| `bin/rails quality:spec` | rspec | green (domain specs are mutation-tested) |
| `bin/rails quality:features` | cucumber | green |
| `bin/rails quality:rubocop` | rubocop omakase | green |
| `bin/rails quality:packwerk` | packwerk | no cross-slice constant refs |
| `bin/rails quality:crap` | crap4r | CRAP ≤ **8** |
| `bin/rails quality:mutant` | mutant (incremental, `SINCE=origin/main`) | **100%** domain coverage; `quality:mutant:full` for full run |
| `bin/rails quality:dry` | dry4r (github.com/Kjeldahl/dry4r) | reduce duplication where reasonable |
| `bin/rails quality:zeitwerk` | zeitwerk:check | green |

- mutant: jobs 4 on in-memory store; jobs 1 if `EVENT_STORE_ADAPTER=postgres`.
- No property-testing framework; add property tests only when explicitly requested.

## Self-logging rake tasks
- Every quality task self-logs via Rakefile helpers (`run_logged`/`sh_logged`):
  full output tee'd to `tmp/logs/<name>-<ISO8601>.log`, last stdout line
  `log: tmp/logs/<file>`. New tasks must use the shared helpers.
- Inspect results by reading/grepping the printed log. Never wrap a task in
  shell redirection, `tee`, or a logging subagent; never re-run a task just to
  read a number.
- Threshold gates (CRAP, mutant coverage): parse the metric from the log, don't
  trust exit status.

## Adding features
Use the `add-feature` skill (`.claude/skills/add-feature/SKILL.md`): specifier →
coder → refactorer → architect, with a read-only reviewer checking the spec
before user approval and the implementation after the architect
(`.claude/agents/`), each in its own git worktree. Teams mode (default; `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in
`.claude/settings.json`) runs them as visible teammates (`teammateMode: auto` → split panes in tmux
or iTerm2); `--subagents` falls back to hidden subagents (automatic in Claude Code
cloud).
