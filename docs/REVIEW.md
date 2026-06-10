# Architecture Review — 2026-06-10

Final review of the five-slice system (identity, accounts, leagues, matches,
scoreboards) against the hard rules in `docs/ARCHITECTURE.md` and the event
catalogue in `docs/DOMAIN.md`. Method: exhaustive grep for cross-namespace
references (`.rb` and `.erb`), read of every controller, every `Events`
module, every projection query and every `EventStore.append` call site, plus
`bin/rails zeitwerk:check` and `bin/rails routes` against the documented
table.

## Verdicts

| # | Rule | Verdict |
|---|---|---|
| 1 | No slice references another slice's constants | **Pass.** Grep for `Identity::`, `Accounts::`, `Leagues::`, `Matches::`, `Scoreboards::` outside each slice's own directory (including all views) finds only the allowed exception: `app/controllers/application_controller.rb:27` → `Identity::Users.find`. All other hits are comments. |
| 2 | web → domain → EventStore; controllers logic-free | **Pass.** No `EventStore`/`DcbEventStore` reference in any controller or view; controllers only parse params, call one command/read model, redirect/render. No domain-class calls from templates (views render only `@ivars` and route helpers; `Matches::MatchesController` exposes `members` via `helper_method`, a thin read-model delegation). |
| 3 | Events are the only cross-slice contract; constructors only in `<Slice>::Events` | **Pass.** `DcbEventStore::Event.new` appears only in the four `domain/events.rb` files (scoreboards owns no events, correctly has no module). All 7 event types' `data` and `tags` match the `docs/DOMAIN.md` table exactly, including email normalisation (`strip.downcase`) in `user_registered` and `player_invited`, and per-player tags on `MatchRegistered`. Cross-slice data needs are met by each slice's own folds over documented types/tags only. |
| 4 | Appends carry an append condition when invariants depend on reads | **Pass.** 7 append sites; 6 use `decision.append_condition` and rescue `DcbEventStore::ConditionNotMet` (register_user, invite_player, accept_invitation, create_league, close_league, register_match). The one unconditioned append, `accounts/domain/create_account.rb:12`, is correct: the account_id is a fresh UUID and no invariant reads prior events (the comment in the file says exactly this). |
| 5 | Zeitwerk | **Pass.** `bin/rails zeitwerk:check` → "All is good!". |
| 6 | Doc matches reality: routing table | **Pass.** `bin/rails routes` output matches the table in `docs/ARCHITECTURE.md` row for row (paths, verbs, controllers, helpers). |
| 7 | Doc matches reality: `Result` shape | **Pass.** `lib/result.rb` is `Data.define(:success, :value, :error)` with `.success(value = nil)` / `.failure(error)` / `success?` / `failure?`, as documented. |
| 8 | Doc matches reality: view-prefix mechanism | **Pass.** `ApplicationController.local_prefixes` appends the demodulized controller path; every `app/slices/*/views` dir exists with a `.keep`; resource dir names are unique across slices and match the documented reservation list. |
| 9 | Membership folds duplicated per slice (constraint #3) | **Pass.** `accounts/`, `leagues/`, `matches/`, `scoreboards/` each define their **own** `<Slice>::Membership` with byte-for-byte identical projections (initial `false`; `AccountCreated`/`InvitationAccepted` → `true`; tags `account:{id}` + `user:{id}`), matching the canonical fold in the doc. Identity correctly has none (not account-scoped). |

## Doc drift fixed (doc-only changes, safe)

`docs/ARCHITECTURE.md` examples had drifted from the code; the rules
themselves had not. Synced:

1. **§6 thin-controller example** showed `< ApplicationController` with
   `before_action :require_authentication`. Reality: every authenticated
   slice has its own `<Slice>::BaseController < ApplicationController`
   (`web/base_controller.rb`) with a slice-local `require_sign_in`
   ("you must be signed in" flash copy). Documented the BaseController
   pattern; `require_authentication` stays as the shared fallback.
2. **§4 `CloseLeague` example** updated to the real implementation
   (`LeagueState.projection(league_id:, account_id:)`, `rejection` helper,
   actual failure messages, single-event append).
3. **§5 `LeagueState` example** updated: keyword args, league **and**
   account tags (tenancy scoping), `extend self` instead of
   `module_function` (the codebase convention — every slice domain module
   uses `extend self`, none use `module_function`), `Query.new(item)`
   without array wrapping (also fixed in the
   §6 canonical membership fold).

No application code was changed.

## Observations (recorded, deliberately not "fixed")

- **Duplicated membership folds are intentional.** Extracting a shared
  `Membership` class would create the exact class-level coupling rule #3
  forbids: four slices would depend on one module, and a change for one
  slice's needs would ripple into the consistency boundaries (append
  conditions!) of the other three. The contract that keeps them in sync is
  the event table in `docs/DOMAIN.md`, not shared code. Same reasoning for
  the league-lifecycle folds (`leagues/league_state.rb`,
  `leagues/league.rb`, `matches/league.rb`, `scoreboards/league_overview.rb`,
  `accounts/account_leagues.rb`) and the `UserRegistered` name lookups
  (`accounts/members.rb`, `matches/account_members.rb`,
  `scoreboards/player_names.rb`): each fold serves a different question and
  shape; only the event contract is shared.
- **Per-slice `BaseController` duplication is intentional** for the same
  reason: each slice owns its rejection copy; the shared surface stays
  minimal (`current_user`, `signed_in?`, `require_authentication`).
- **`ApplicationController#require_authentication` currently has no
  call site** (all slices use their own `require_sign_in`). Kept: it is the
  documented shared fallback and removing shared surface during a final
  review buys nothing. Candidate for removal if a sixth slice also brings
  its own gate.
- **Mutant excludes controllers** (per `.mutant.yml`); the architecture
  compensates by keeping controllers logic-free — verified above, so the
  exclusion remains sound.

## Adding a sixth slice — checklist

1. Create `app/slices/<slice>/{domain,web,views}` **with `.keep` files** —
   the views dir must exist at boot (view paths are wired in
   `config/application.rb`; `domain/` and `web/` are collapsed namespaces).
2. Pick `views/<resource>/` names that are **unique across all slices**
   (one shared lookup path) and add them to the reservation list in
   ARCHITECTURE.md §1.
3. Add routes in `config/routes.rb` under `scope module: :<slice>` **and**
   the same rows to the routing table in ARCHITECTURE.md §6.
4. If the slice serves account-scoped pages: copy the canonical membership
   fold into `<Slice>::Membership` (do not reference `Accounts::*`), add a
   private `require_account_member!` in the controller, and check
   membership again inside every command's decision model.
5. If the slice requires sign-in: give it a
   `<Slice>::BaseController < ApplicationController` with its
   `require_sign_in` (or use the shared `require_authentication`).
6. If the slice owns events: one `domain/events.rb` with one constructor
   per type, and add the types/data/tags to the table in `docs/DOMAIN.md`
   **first** — that table is the integration contract others will fold.
7. Every command: validate input → `EventStore.decide` → invariants →
   append **with** `decision.append_condition` → rescue `ConditionNotMet`;
   return `Result`. Unconditioned appends only when nothing was read
   (document why, as `CreateAccount` does).
8. Mirror specs under `spec/slices/<slice>/`, steps in
   `features/step_definitions/<slice>_steps.rb`; run `bin/rails
   zeitwerk:check` and `rake quality` (rspec, cucumber, crap4r ≤ 8,
   mutant on the slice's domain).

## Test status after review

- `bundle exec rspec` — 355 examples, 0 failures.
- `bundle exec cucumber` — 64 scenarios, all passing.
- `bin/rails zeitwerk:check` — pass.
