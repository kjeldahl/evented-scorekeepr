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

## Standings & statistics (per league)

For each player: rank (by points, ties share order by name), points, matches
played, wins, losses, win percentage, points scored (game points for),
points conceded (against), and current streak (e.g. W3 / L2).

The league page shows the scoreboard plus the most recent matches.

## Events

| Event | Data | Tags |
|---|---|---|
| `UserRegistered` | user_id, name, email, password_digest | `user:{user_id}`, `user_email:{email}` |
| `UserHandleSet` | user_id, handle | `user:{user_id}` |
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
  matches and view the account, its leagues and scoreboards.
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

## Slices

| Slice | Responsibility |
|---|---|
| `identity` | sign up, sign in / out |
| `accounts` | create account, invite players, accept invitations, membership |
| `leagues` | create / close leagues |
| `matches` | register match results (optimised for fast input) |
| `scoreboards` | standings, statistics, recent matches |
| `statistics` | per-player league statistics: form, head-to-head, history |
