# Scorekeepr Architecture

Scorekeepr is a Rails 8.1 app with **no ActiveRecord**. All persistence is the
append-only DCB event store (`dcb_event_store` gem), accessed only through
`EventStore` (`lib/event_store.rb`). The domain language, event catalogue and
invariants live in `docs/DOMAIN.md` — this document defines *how* code is
organised and written. Coder agents must follow it exactly.

The dependency direction is always:

```
web (controllers, views)  →  domain (commands, events, projections)  →  EventStore
```

## 1. Vertical slices

The app is built in five slices under `app/slices/`:

| Slice | Namespace | Responsibility | Events it owns (appends) |
|---|---|---|---|
| `identity` | `Identity` | sign up, sign in / out, profile (handle), super admin grant | `UserRegistered`, `UserHandleSet`, `SuperAdminGranted` |
| `accounts` | `Accounts` | dashboard, create account, invite, accept/revoke/decline, leave, membership | `AccountCreated`, `PlayerInvited`, `InvitationAccepted`, `InvitationRevoked`, `InvitationDeclined`, `MemberLeft` |
| `leagues` | `Leagues` | create / rename / close leagues | `LeagueCreated`, `LeagueRenamed`, `LeagueClosed` |
| `matches` | `Matches` | register match results | `MatchRegistered` |
| `scoreboards` | `Scoreboards` | league page: standings, statistics, recent matches | *(none — read only)* |

### Slice layout

```
app/slices/<slice>/
  domain/          # pure Ruby: commands, the Events module, projections/read models
  web/             # controllers only
  views/<resource>/  # ERB templates for that slice's controllers
```

Autoloading (already wired in `config/application.rb`): `domain/` and `web/`
are **collapsed**, so `app/slices/leagues/domain/create_league.rb` defines
`Leagues::CreateLeague` and `app/slices/leagues/web/leagues_controller.rb`
defines `Leagues::LeaguesController`. Every `app/slices/*/views` directory is
appended to the view paths **at boot** — the directory must exist (each has a
`.keep`; never delete them).

Template lookup: `ApplicationController.local_prefixes` adds the demodulized
controller name, so `Leagues::LeaguesController#new` renders
`app/slices/leagues/views/leagues/new.html.erb`. Because all slice view dirs
share one lookup path, **resource directory names under `views/` must be
unique across slices**. The reserved names per the routing table below:

- identity: `views/registrations/`, `views/sessions/`, `views/profiles/`
- accounts: `views/dashboard/`, `views/accounts/`, `views/invitations/`, `views/pending_invitations/`
- leagues: `views/leagues/`
- matches: `views/matches/`
- scoreboards: `views/scoreboards/`
- statistics: `views/players/`

`domain/` is **pure Ruby**: no Rails controller/view/helper code, no
references to `params`, `session` or routes. It may use `EventStore`,
`DcbEventStore::*` value objects, `Result`, stdlib (e.g. `SecureRandom`) and
`bcrypt` (identity only).

## 2. Dependency rules

1. `web → domain → EventStore`. Controllers contain **no domain logic** — no
   folding, no invariant checks, no event construction.
2. A slice may **subscribe to / fold other slices' event types and tags**
   exactly as catalogued in `docs/DOMAIN.md`. Events are the *only*
   integration contract between slices.
3. A slice must **never reference another slice's classes** — not its
   commands, projections, `Events` module, controllers or views. If you need
   another slice's data, fold its events yourself inside your own `domain/`.
4. **Single exception:** `ApplicationController#current_user` calls
   `Identity::Users.find(user_id)` — the identity slice's public reader. It
   returns a user value object responding to `id`, `name`, `email`,
   `handle`, or `nil`.
   No other cross-slice class reference is permitted anywhere.
5. Slice controllers may use the shared helpers `ApplicationController`
   provides (`current_user`, `signed_in?`, `require_authentication`) and
   nothing else from outside their slice.
6. Shared UI lives only in `app/views/layouts/` and
   `app/assets/stylesheets/application.css`. Shared infrastructure lives only
   in `lib/` (`EventStore`, `Result`).

## 3. Event conventions

- Event **type names are strings in PascalCase, past tense**:
  `"UserRegistered"`, `"LeagueClosed"`. Events are immutable facts; they are
  never updated or deleted.
- Each slice has exactly **one `<Slice>::Events` module**
  (`app/slices/<slice>/domain/events.rb`) with **one constructor method per
  event type it owns**, returning a `DcbEventStore::Event` with the exact
  `type`, `data` and `tags` from the table in `docs/DOMAIN.md`. Only this
  module builds those events; only this slice appends them.
- Event `data` is a Hash with symbol keys (the store round-trips JSON with
  `symbolize_names: true`, so handlers read `event.data[:league_id]`).
- Tags are strings of the form `kind:value` (`"league:#{league_id}"`).
  Emails are normalised (`email.strip.downcase`) before use in data or tags.

Example:

```ruby
# app/slices/leagues/domain/events.rb
module Leagues
  module Events
    extend self

    def league_created(league_id:, account_id:, name:, game_type:, starting_points:, stake_percentage:)
      DcbEventStore::Event.new(
        type: "LeagueCreated",
        data: { league_id:, account_id:, name:, game_type:, starting_points:, stake_percentage: },
        tags: [ "league:#{league_id}", "account:#{account_id}" ]
      )
    end

    def league_closed(league_id:, account_id:)
      DcbEventStore::Event.new(
        type: "LeagueClosed",
        data: { league_id:, account_id: },
        tags: [ "league:#{league_id}", "account:#{account_id}" ]
      )
    end
  end
end
```

## 4. Command pattern

One command class per use case, named after it: `Identity::RegisterUser`,
`Accounts::CreateAccount`, `Leagues::CreateLeague`, `Matches::RegisterMatch`,
… Each exposes a single class method `.call(...)` (keyword arguments) and
returns a **`Result`** (defined in `lib/result.rb`):

```ruby
Result = Data.define(:success, :value, :error)
Result.success(value = nil)  # => success? == true,  value = primary id/payload, error = nil
Result.failure(error)        # => failure? == true,  value = nil, error = human-readable String
```

- `value` on success is the primary identifier the web layer needs to
  redirect (e.g. the new `league_id`); `nil` when there is nothing to return.
- `error` on failure is a user-presentable message the controller puts in
  `flash.alert`. Use `Result.failure` for *all* expected failures (validation,
  invariant violation, concurrency conflict). Commands never raise for
  business rule violations.

Command body — always this shape:

1. Normalise/validate **input shape** (presence, integer ranges, email
   format). Invalid input → `Result.failure(...)`, nothing is read or written.
2. Build a **decision model** from one or more named projections:
   `decision = EventStore.decide(open: league_open, member: membership)`.
3. Check **invariants against the folded states**
   (`decision.states[:open]`, …). Violation → `Result.failure(...)`. **A
   failed command never appends.**
4. Append the new event(s) **with the decision model's append condition**:
   `EventStore.append(events, decision.append_condition)`. The condition
   covers everything the projections read, so a concurrent conflicting append
   fails — rescue `DcbEventStore::ConditionNotMet` and return
   `Result.failure("Someone changed ... — please retry.")`. Never enforce
   uniqueness or state checks by read-then-write without the condition.

```ruby
# app/slices/leagues/domain/close_league.rb
module Leagues
  class CloseLeague
    def self.call(league_id:, account_id:, user_id:)
      decision = EventStore.decide(
        league: LeagueState.projection(league_id:, account_id:),
        member: Membership.projection(account_id:, user_id:)
      )
      failure = rejection(decision.states)
      return failure if failure

      EventStore.append(Events.league_closed(league_id:, account_id:), decision.append_condition)
      Result.success(league_id)
    rescue DcbEventStore::ConditionNotMet
      Result.failure("the league is closed")
    end

    def self.rejection(states)
      return Result.failure("only members can close leagues") unless states.fetch(:member)
      return Result.failure("the league was not found") if states.fetch(:league) == :none

      Result.failure("the league is closed") if states.fetch(:league) == :closed
    end
    private_class_method :rejection
  end
end
```

`EventStore.append` accepts a single event or an array; the condition is
always the decision model's `append_condition`.

IDs are UUIDs generated **inside the command** with `SecureRandom.uuid` (the
event id is generated by `DcbEventStore::Event` itself).

## 5. Projection pattern (read models)

Read models are classes/modules in `domain/` exposing **query methods** that
fold `DcbEventStore::Projection` objects via `EventStore.project` (read-only
paths) or `EventStore.decide` (inside commands, to get the append condition):

```ruby
# app/slices/leagues/domain/league_state.rb
module Leagues
  module LeagueState
    extend self

    def projection(league_id:, account_id:)
      DcbEventStore::Projection.new(
        initial_state: :none,
        handlers: {
          "LeagueCreated" => ->(_state, _event) { :open },
          "LeagueClosed" => ->(_state, _event) { :closed }
        },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(
            event_types: %w[LeagueCreated LeagueClosed],
            tags: [ "league:#{league_id}", "account:#{account_id}" ]
          )
        )
      )
    end
  end
end
```

Rules:

- Initial state is a plain Ruby value (symbol, Hash, Array, `Data` struct).
  Handlers are pure functions `(state, event) → state`; no IO, no clock, no
  randomness inside handlers.
- Query items must carry the **narrowest tags possible** — the append
  condition is built from the query, so an over-broad query causes spurious
  concurrency conflicts.
- Read models never cache across requests; state is always folded fresh from
  the store (the events table is the only state).
- Folding **other slices' events** is done by writing your own projection
  over their documented types/tags (e.g. scoreboards folds `MatchRegistered`;
  every slice folds `AccountCreated`/`InvitationAccepted` for membership).
  Copy the contract from `docs/DOMAIN.md`, not classes from the other slice.

## 6. Web conventions

### Thin controllers

Controllers do exactly: parse/permit params → call one command or read model →
redirect or render with flash. Pattern:

```ruby
module Leagues
  class LeaguesController < BaseController   # slice-local auth gate, see below
    before_action :require_account_member!

    def create
      result = CreateLeague.call(user_id: current_user.id, **league_params)
      if result.success?
        redirect_to account_league_scoreboard_path(params[:account_id], result.value), notice: "League created."
      else
        flash.now[:alert] = result.error
        render :new, status: :unprocessable_entity
      end
    end
  end
end
```

Every slice that requires sign-in has its own
`<Slice>::BaseController < ApplicationController`
(`app/slices/<slice>/web/base_controller.rb`) whose `before_action
:require_sign_in` redirects guests to `/login` with the slice's flash copy
("you must be signed in"). `ApplicationController#require_authentication`
remains available as the shared fallback, but slices currently own their
gate so the wording can differ per feature without touching shared code.

### Authentication & tenancy

- Sessions: `session[:user_id]` is set by `Identity::SessionsController` /
  `Identity::RegistrationsController` on sign-in/up and cleared on sign-out.
  Identity is the only slice that writes `session[:user_id]`.
- `ApplicationController` provides **only** `current_user`, `signed_in?`
  (both helper methods) and `require_authentication` (before_action that
  redirects to `/login` with a flash alert). It contains **no domain logic**
  and **no membership/tenancy logic**.
- **Account membership is enforced by each slice itself.** There is no shared
  `require_account_member!` in `ApplicationController` — that would force a
  class dependency on the accounts slice. Instead, every slice that serves
  account-scoped pages defines its **own** private membership read model in
  its `domain/`, folding the accounts slice's *events* (the shared contract
  per `docs/DOMAIN.md`): a user is a member of an account iff the latest
  membership event tagged `account:{id}` + `user:{user_id}` grants it —
  `AccountCreated` (the owner) and `InvitationAccepted` grant membership,
  `MemberLeft` ends it (a later accepted invitation grants it again).
  The canonical fold (duplicate this per slice — do not share the class):

```ruby
def projection(account_id:, user_id:)
  DcbEventStore::Projection.new(
    initial_state: false,
    handlers: {
      "AccountCreated"     => ->(_s, _e) { true },
      "InvitationAccepted" => ->(_s, _e) { true },
      "MemberLeft"         => ->(_s, _e) { false }
    },
    query: DcbEventStore::Query.new(
      DcbEventStore::QueryItem.new(
        event_types: %w[AccountCreated InvitationAccepted MemberLeft],
        tags: [ "account:#{account_id}", "user:#{user_id}" ]
      )
    )
  )
end
```

  Each slice controller adds its own `before_action :require_account_member!`
  (private method in that controller) using its own fold; commands ALSO check
  membership in their decision model (defence in depth — the command is the
  consistency boundary, the before_action is UX).
- Accounts slice **owns** (appends) the membership events; everyone else only
  folds them.
- **Super admin read access** (see `docs/DOMAIN.md` § Super admin): exactly
  three *view-only* gates also open for super admins —
  `Accounts::AccountsController#show`, `Scoreboards::ScoreboardsController#show`
  and `Statistics::PlayersController#show`. Their `require_account_member!`
  passes when the user is a member **or** a super admin. Every other
  member gate (invitations new/create, invitation revocations, on-behalf
  acceptances, account leavings, league new/create/edit/update/close,
  match new/create) stays membership-only, and **no command consults super
  admin status** — a super admin is simply not a member. Each of the three
  slices defines its **own** `<Slice>::SuperAdmin` read model (duplicate
  per slice, like `Membership` — never share the class), folding the
  identity slice's `SuperAdminGranted` by tag. The canonical fold:

```ruby
def projection(user_id:)
  DcbEventStore::Projection.new(
    initial_state: false,
    handlers: { "SuperAdminGranted" => ->(_s, _e) { true } },
    query: DcbEventStore::Query.new(
      DcbEventStore::QueryItem.new(
        event_types: %w[SuperAdminGranted],
        tags: [ "user:#{user_id}" ]
      )
    )
  )
end
```

  The gate keeps the membership answer it already folded (e.g.
  `@member = Membership.member?(...)`) and the three views use it to hide
  write affordances from non-member viewers (invite/new-league links on the
  account page, register-match link and close-league button on the
  scoreboard page) — the links would only redirect anyway; the real
  enforcement stays in the member gates and command invariants.
  Granting has **no web UI and no route**: `Identity::GrantSuperAdmin.
  call(user_id:)` (identity domain) is called from cucumber steps, console
  or seeds only.
- **All-accounts list (discovery)**: `GET /accounts` ->
  `Accounts::AccountsController#index` is the one **super-admin-only** page
  (everything else stays member-or-super-admin or member-only). The gate is
  a controller-private `require_super_admin!` (before_action on `index`
  only) using the slice's existing `Accounts::SuperAdmin` fold; non-super
  admins (members included) are redirected like any other refused gate.
  The reader is `Accounts::AllAccounts` (`accounts/domain/all_accounts.rb`):
  a read-only projection over **all** `AccountCreated` events (event type
  only, no tags; acceptable outside commands since this fold never feeds an
  append condition) returning `{id, name}` value objects sorted
  alphabetically by name. View: `accounts/views/accounts/index.html.erb`,
  account names linking to `account_path` and nothing else (no write
  affordances). `Accounts::DashboardController#show` folds
  `Accounts::SuperAdmin` to show the dashboard link to the list only for
  super admins. Membership and commands are untouched; the list grants
  nothing beyond the existing view-only access.

### Routing table

The complete route map (`config/routes.rb` implements exactly this; keep both
in sync). All routes except signup/login require authentication.

| Verb | Path | Controller#action | Helper | Purpose |
|---|---|---|---|---|
| GET | `/up` | `rails/health#show` | `rails_health_check_path` | health check |
| GET | `/signup` | `identity/registrations#new` | `signup_path` | sign-up form |
| POST | `/signup` | `identity/registrations#create` | — | register; signs in; → root |
| GET | `/login` | `identity/sessions#new` | `login_path` | sign-in form |
| POST | `/login` | `identity/sessions#create` | — | sign in; → root |
| DELETE | `/logout` | `identity/sessions#destroy` | `logout_path` | sign out; → login |
| GET | `/profile` | `identity/profiles#show` | `profile_path` | profile page: set the display handle |
| POST | `/profile` | `identity/profiles#update` | — | set handle; → profile |
| GET | `/` | `accounts/dashboard#show` | `root_path` | my accounts + my pending invitations; super admins also get a link to the all-accounts list |
| GET | `/accounts` | `accounts/accounts#index` | `accounts_path` | **super admin only**: read-only all-accounts list (alphabetical by name), each linking to its account page |
| GET | `/accounts/new` | `accounts/accounts#new` | `new_account_path` | new-account form |
| POST | `/accounts` | `accounts/accounts#create` | `accounts_path` | create account; → account page |
| GET | `/accounts/:id` | `accounts/accounts#show` | `account_path` | account home: leagues list, members, outgoing invitations, invite + new-league links |
| GET | `/accounts/:account_id/invitations/new` | `accounts/invitations#new` | `new_account_invitation_path` | invite-player form |
| POST | `/accounts/:account_id/invitations` | `accounts/invitations#create` | `account_invitations_path` | invite player; → account page |
| POST | `/accounts/:account_id/invitations/:invitation_id/revoke` | `accounts/invitation_revocations#create` | `revoke_account_invitation_path` | revoke outgoing invitation; → account page |
| POST | `/accounts/:account_id/leave` | `accounts/account_leavings#create` | `leave_account_path` | leave the account; → dashboard |
| GET | `/invitations` | `accounts/pending_invitations#index` | `pending_invitations_path` | my pending invitations (by my email) |
| POST | `/invitations/:invitation_id/accept` | `accounts/invitation_acceptances#create` | `accept_invitation_path` | accept; → that account page |
| POST | `/invitations/:invitation_id/decline` | `accounts/invitation_declines#create` | `decline_invitation_path` | decline; → dashboard |
| POST | `/accounts/:account_id/invitations/:invitation_id/accept_on_behalf` | `accounts/on_behalf_acceptances#create` | `accept_account_invitation_on_behalf_path` | **dev/test only** (not routed in production): accept an outgoing invitation on behalf of the invited player; → account page |
| GET | `/accounts/:account_id/leagues/new` | `leagues/leagues#new` | `new_account_league_path` | new-league form |
| POST | `/accounts/:account_id/leagues` | `leagues/leagues#create` | `account_leagues_path` | create league; → **scoreboard page** |
| GET | `/accounts/:account_id/leagues/:id/edit` | `leagues/leagues#edit` | `edit_account_league_path` | rename-league form |
| PATCH/PUT | `/accounts/:account_id/leagues/:id` | `leagues/leagues#update` | `account_league_path` | rename league; → scoreboard page |
| POST | `/accounts/:account_id/leagues/:id/close` | `leagues/leagues#close` | `close_account_league_path` | close league; → scoreboard page |
| GET | `/accounts/:account_id/leagues/:league_id/scoreboard` | `scoreboards/scoreboards#show` | `account_league_scoreboard_path` | **the league page**: standings table, recent matches, "Register match" link, "Close league" button |
| GET | `/accounts/:account_id/leagues/:league_id/matches/new` | `matches/matches#new` | `new_account_league_match_path` | register-match form |
| POST | `/accounts/:account_id/leagues/:league_id/matches` | `matches/matches#create` | `account_league_matches_path` | register match; → scoreboard page |
| GET | `/accounts/:account_id/leagues/:league_id/players/:player_id` | `statistics/players#show` | `account_league_player_path` | player statistics: points/rank, form, head-to-head, match history |

**League page ownership — decided, do not re-litigate:** the leagues slice
owns league *lifecycle* (new/create/close forms and commands) and has **no
show page**. The league **show page is the scoreboard page**, owned by the
scoreboards slice (`GET .../scoreboard`). League create, league close and
match create all redirect to `account_league_scoreboard_path`. The accounts
slice's account page lists the account's leagues (its own fold of
`LeagueCreated`/`LeagueClosed`) linking each to its scoreboard page.

### Views & styling

The shared layout (`app/views/layouts/application.html.erb`) renders header,
nav, flash and a `main.container`; slice templates render page content only.
Use the existing CSS (`app/assets/stylesheets/application.css`): `.card` for
boxed sections, tables get striped rows for free, add class `num` to
numeric `th`/`td` (right-aligned tabular numerals), `.actions` for
button/link rows, `.muted` for secondary text. Forms: label above input,
plain `form_with` (no JS framework; full page loads are fine). No new CSS
frameworks; extend `application.css` sparingly if a slice truly needs it.

## 7. Testing & quality gates

- **RSpec** unit specs, one per domain class, mirrored under
  `spec/slices/<slice>/` (e.g. `spec/slices/leagues/create_league_spec.rb`
  for `Leagues::CreateLeague`). Tag examples that touch the store with
  `:event_store` — the suite wipes the store (`EventStore.reset!`) for those.
  Test commands by appending given events, calling `.call`, asserting on the
  `Result` and on `EventStore.read`. Test projections as pure folds where
  possible (`projection.fold(events)` needs no database).
- **Cucumber** features describe user-visible behaviour; step definitions per
  slice in `features/step_definitions/<slice>_steps.rb`; shared world helpers
  (Capybara session helpers, builders like "a signed-in member of account X")
  in `features/support/`. The store is reset before every scenario.
- **Quality gate**: `rake quality` runs, in order: `rspec`, `cucumber`,
  `crap4r` (CRAP threshold **8** over `app/slices` and `lib`), and `mutant`
  against slice domain code. All four must pass before a slice is done —
  domain code (commands, projections, Events) is what mutant covers, another
  reason to keep controllers logic-free.

## 8. Hard constraints (summary for coders)

1. No ActiveRecord, no migrations, no models in `app/models`. The event store
   is the only persistence; `EventStore` is the only way to touch it.
2. Never write without an append condition when an invariant depends on what
   you read. Validation failures never append.
3. Never reference another slice's classes; fold its events instead. Sole
   exception: `ApplicationController → Identity::Users.find`.
4. One `Events` module per slice; only the owning slice appends its events;
   types/data/tags exactly as in `docs/DOMAIN.md`.
5. Commands return `Result`; controllers stay thin; membership checks live in
   each slice (controller before_action + command invariant).
6. Keep `config/routes.rb` and the routing table above in sync; slice `views/`
   resource dirs must keep the documented unique names; never delete the
   `.keep` files in `app/slices/*/{domain,web,views}`.
