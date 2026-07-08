# Scorekeepr Domain

Scorekeepr is a SaaS for keeping score in office/family tournaments and
leagues (foosball, table tennis, ...). It is fully event sourced on the DCB
event store (`dcb_event_store`): the append-only `events` table is the only
persistence; every read model is a projection folded from events.

## Concepts

- **User** — a person with an email + password. Registers once, can belong to
  many accounts.
- **Account** — a tenant (an office, a family). Created by a user, who becomes
  its owner. Users are invited into accounts by email and become **members**
  (players) when they accept.
- **League** — lives in an account, is for one game type (e.g. "Foosball",
  "Table Tennis"). An account can host many leagues, also for the same game
  type. A league runs until it is explicitly closed; the end need not be known
  up front. Matches can only be registered in open leagues.
- **Match** — a result registered in a league: home side vs away side, each
  side 1 or 2 players (so 1v1 and 2v2 are supported), with a score like 21-8.
  Draws are not allowed; the score decides the winner. All players in a match
  must be distinct members of the account.

## Scoring (zero-sum stake model)

"Each player scores points by getting a percentage of the opponents' points
if they win."

- A league has `starting_points` (default 1000) and `stake_percentage`
  (default 10).
- A player enters the league standings with `starting_points` the first time
  they appear in a registered match.
- When a match is registered:
  - Each **losing** player stakes `stake_percentage`% of their current
    points, rounded down: `stake = (points * stake_percentage) / 100`
    (integer division). Each loser loses their stake.
  - The **pot** (sum of all stakes) is split among the winning players:
    each winner gains `pot / winners_count` (integer division); the
    remainder is handed out one point at a time to winners in the order
    they were listed on the match.
- Scoring is derived: it is folded from `MatchRegistered` events in league
  order; no separate scoring events are stored.

### Editing a match result

Any player who took part in a match can correct its score while the league
is open. Only the score changes; the players and the sides are fixed. Any
match in the league can be corrected, not just the latest: a correction is a
`MatchResultCorrected` event folded onto its `MatchRegistered` (matched by
`match:{match_id}`), so the whole league re-folds in order and every later
standing re-derives from the corrected scores. A corrected score obeys the
same rules as a freshly registered one: non-negative integers and no draws.
Editing is authorised by match participation (a non-participant, member or
not, is rejected with "only players in the match can edit it"), never by a
separate membership check.

### Deleting a match result

Any player who took part in a match can also delete it while the league is
open, mirroring editing. A deletion is a `MatchDeleted` event folded onto its
`MatchRegistered` (matched by `match:{match_id}`), so the whole league
re-folds in order as if the match had never been registered: it vanishes from
the recent matches and every later standing re-derives, and a player who only
ever appeared in the deleted match drops out of the standings entirely. A
deleted match is gone: it can no longer be deleted or edited (both are
rejected with "the match was not found"). Like editing, deleting is authorised
by match participation (a non-participant, member or not, is rejected with
"only players in the match can delete it"), never by a separate membership
check; and it is refused in a closed league ("the league is closed").

## Standings & statistics (per league)

For each player: rank (by points, ties share order by name), points, matches
played, wins, losses, win percentage, points scored (game points for),
points conceded (against), and current streak (e.g. W3 / L2).

The league page shows the scoreboard plus the most recent matches.

### TV dashboard

Each league also has a **TV dashboard** — a full-screen, read-only page
meant for a screen in the room where games are played, reached via the
"TV mode" link on the league's scoreboard page (shown to every viewer of
that page, members and super admins alike). It shows:

- The league name, game type and an open/closed badge.
- A **leader spotlight**: the rank-1 player with their points.
- A **hot-streak spotlight**: the player with the longest *current* winning
  streak of at least 2; hidden when nobody has one; ties broken by
  standings order.
- The standings table.
- The latest 5 matches, newest first.

The page auto-refreshes: updates are **pushed over a websocket** whenever a
league event is appended — i.e. whenever a match is registered, corrected or
deleted or the league is renamed or closed. The per-league **version** - a
monotonic count of the league's events (`LeagueCreated`, `LeagueRenamed`,
`LeagueClosed`, `MatchRegistered`, `MatchResultCorrected`, `MatchDeleted`
tagged `league:{id}`) - remains the catch-up contract:
on websocket (re)connect the page fetches it once and reloads when it
differs from the version it last rendered, covering updates missed while
disconnected. The version is a pure read-model fold and the push is
infrastructure, not an event: no new events are introduced and the version
never feeds an append condition.

## Events

| Event | Data | Tags |
|---|---|---|
| `UserRegistered` | user_id, name, email, password_digest | `user:{user_id}`, `user_email:{email}` |
| `UserHandleSet` | user_id, handle | `user:{user_id}` |
| `SuperAdminGranted` | user_id | `user:{user_id}` |
| `AccountCreated` | account_id, name, owner_user_id | `account:{account_id}`, `user:{owner_user_id}` |
| `PlayerInvited` | invitation_id, account_id, email, invited_by_user_id | `invitation:{invitation_id}`, `account:{account_id}`, `invitee_email:{email}` |
| `InvitationAccepted` | invitation_id, account_id, user_id | `invitation:{invitation_id}`, `account:{account_id}`, `user:{user_id}` |
| `InvitationRevoked` | invitation_id, account_id, revoked_by_user_id | `invitation:{invitation_id}`, `account:{account_id}` |
| `InvitationDeclined` | invitation_id, account_id, user_id | `invitation:{invitation_id}`, `account:{account_id}` |
| `MemberLeft` | account_id, user_id | `account:{account_id}`, `user:{user_id}` |
| `LeagueCreated` | league_id, account_id, name, game_type, starting_points, stake_percentage | `league:{league_id}`, `account:{account_id}` |
| `LeagueRenamed` | league_id, account_id, name | `league:{league_id}`, `account:{account_id}` |
| `LeagueClosed` | league_id, account_id | `league:{league_id}`, `account:{account_id}` |
| `MatchRegistered` | match_id, league_id, account_id, home_player_ids, away_player_ids, home_score, away_score, registered_by_user_id | `match:{match_id}`, `league:{league_id}`, `account:{account_id}`, `player:{id}` per player |
| `MatchResultCorrected` | match_id, league_id, account_id, home_score, away_score, corrected_by_user_id | `match:{match_id}`, `league:{league_id}`, `account:{account_id}` |
| `MatchDeleted` | match_id, league_id, account_id, deleted_by_user_id | `match:{match_id}`, `league:{league_id}`, `account:{account_id}` |
| `ImpersonationStarted` | impersonation_id, super_admin_user_id, impersonated_user_id, account_id | `impersonation:{impersonation_id}`, `user:{super_admin_user_id}`, `impersonated_user:{impersonated_user_id}`, `account:{account_id}` |
| `ImpersonationEnded` | impersonation_id, super_admin_user_id | `impersonation:{impersonation_id}`, `user:{super_admin_user_id}` |
| `ImpersonatedActionRecorded` | impersonation_id, super_admin_user_id, impersonated_user_id, actions (each `{type, tags}`) | `impersonation:{impersonation_id}`, `user:{super_admin_user_id}` |

Emails are normalised (lowercased, stripped) before being used in data or
tags. Uniqueness (e.g. one user per email, one membership per account) is
enforced with DCB append conditions, never with read-then-write races.

## Invariants

- An email can register only once (`user_email:` tag + append condition).
- Account membership: the owner is a member from creation; an invitation can
  be accepted only once, only by a signed-in user whose email matches. An
  invitation is **settled** once it is accepted, revoked (by a member) or
  declined (by the invited user) — a settled invitation cannot be accepted,
  revoked or declined again. Declining requires the matching email, like
  accepting.
- Any member — the owner included — can leave an account (`MemberLeft`).
  Membership is the *latest* of the membership events in order:
  `AccountCreated`/`InvitationAccepted` grant it, `MemberLeft` ends it, and a
  later accepted invitation grants it again. Leaving changes no history:
  registered matches, standings and statistics keep showing the departed
  player; they just stop being a selectable member and lose access.
- Only account members can create, rename and close leagues, register
  matches and view the account, its leagues and scoreboards. **Sole
  exception:** a super admin (see below) may additionally *view* any
  account, its leagues, scoreboards and player statistics without being a
  member — viewing only; every write invariant above stays membership-based
  and is untouched.
- League names must be present (create and rename alike); starting_points > 0;
  0 < stake_percentage < 100. Only open leagues can be renamed.
- Matches: sides have 1 or 2 players each, all players distinct account
  members, scores are non-negative integers, no draws, league must be open.

## Display names (handles)

A user may set a **handle** on their profile (`UserHandleSet`, latest wins;
handle must be present). Wherever *players* are displayed — account members,
match-form player pickers, scoreboards, recent-match lines and player
statistics — the handle is shown instead of the registered name; users
without a handle are shown by name. The registered name and email remain the
identity facts (sign-in, invitations by email).

## Player statistics (per league)

Every player name on a scoreboard links to that player's statistics page in
the league (member-only, like the scoreboard). The page shows:

- Current points and rank in the league, and matches played.
- **Form**: the player's last five results, most recent first, rendered like
  `W W L W L` (fewer if fewer matches played).
- **Head-to-head**: one row per opponent the player has faced (an opponent is
  any player on the other side, in 1v1 and 2v2 alike): played, won, lost
  against that opponent. Ordered by most played, then name.
- **Match history**: all of the player's matches, newest first, each with the
  result line ("Alice beats Bob 21-8") and the player's points after that
  match (the running balance from the stake fold).

Player statistics are pure folds over `MatchRegistered` (+ `LeagueCreated`
for the starting configuration); no new events are introduced.

## Super admin

A **super admin** is a user who may *view* every account — the account page
(members, leagues, outgoing invitations), every scoreboard, every TV
dashboard and every player statistics page — without being a member. For discovery, a super
admin's dashboard links to a read-only **all-accounts list** naming every
account in the system (alphabetically by name); opening an account from it
is the same view-only access. Ordinary users never see this list. The
privilege is strictly read-only:

- It grants **no membership**: a super admin never appears in member lists,
  is never selectable as a player, never appears on scoreboards or in
  statistics, and "all players must be members" rejects them like any other
  non-member.
- It grants **no write privileges**: creating/renaming/closing leagues,
  registering matches, inviting/revoking and leaving remain member-only —
  the membership invariants in commands are unchanged and never consult
  super admin status.
- A super admin who is *also* an ordinary member of some account behaves
  like any other member there.

The fact is the `SuperAdminGranted` event (identity slice owns it; tag
`user:{user_id}`); super admin status is `true` iff at least one
`SuperAdminGranted` exists for the user. Granting is a domain-level command
(`Identity::GrantSuperAdmin.call(user_id:)`) with **no web UI and no route**
— it is invoked from cucumber steps, the console or seed tasks. The command
is idempotent: granting an existing super admin succeeds without appending.
**Revocation is deliberately deferred**: no `SuperAdminRevoked` event exists
yet because no behaviour requires it; when it is needed, add the event to
the table above and the status fold becomes latest-wins (like
`MemberLeft` for membership).

### Impersonation

Impersonation is the **one deliberate, audited exception** to super admin
being read-only. A super admin may *impersonate* a member of an account and
then act as that member:

- The entry point is an **"Impersonate" button on each member row of an
  account's members list**, shown only to a super admin (never to an
  ordinary member) and never on the super admin's own row. Starting
  impersonation is the only new command that consults super admin status;
  attempting it as a non-super-admin is rejected with "only super admins can
  impersonate players".
- Once started, impersonation is a **whole-session identity**: the super
  admin becomes that member everywhere until they escape, including in the
  member's other accounts. Every page shows a clear notification of who is
  being impersonated with a "Stop impersonating" button next to it; escaping
  ends the session and restores the super admin's own (read-only) identity.
  Signing out also ends the impersonation session (it ends the super admin's
  own login), so a signed-out user never keeps the impersonation notice.
- While impersonating, **every action is performed with the impersonated
  member's privileges and attributed to that member** — the member-gated
  commands are unchanged and still see the member as the actor (they never
  consult super admin status). A super admin therefore gains no privilege of
  their own; they borrow the member's. All the read-only guarantees above
  still hold for a super admin acting *as themselves*.
- Impersonation is **audited**. Starting and ending a session are the
  `ImpersonationStarted` / `ImpersonationEnded` events above. Every write
  performed while impersonating is also recorded against the real super
  admin behind it as a **dedicated `ImpersonatedActionRecorded` audit event**
  (the open choice resolved in favour of a per-action audit event over
  attribution carried on the action events, so the member-gated commands stay
  unchanged and impersonation-agnostic). It captures the appended action(s)
  (each event's type and tags) tagged with the impersonation and the super
  admin. There is no in-app view of the audit trail yet.

## Slices

| Slice | Responsibility |
|---|---|
| `identity` | sign up, sign in / out, super admin grant |
| `accounts` | create account, invite players, accept invitations, membership |
| `leagues` | create / close leagues |
| `matches` | register match results (optimised for fast input), correct and delete them |
| `scoreboards` | league page + TV dashboard: standings, statistics, recent matches, live version |
| `statistics` | per-player league statistics: form, head-to-head, history |
