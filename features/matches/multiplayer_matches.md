# Multiplayer Matches Specification

## Problem

Scorekeepr currently supports only 1v1 and 2v2 head-to-head matches. We need
a **multiplayer** mode where N players each enter a score, are ranked by score,
and points are distributed based on finishing position.

## Scope

- **New domain concept:** `MultiplayerMatch` — a separate concept from `Match`
  (no shared base, no subclass). Separate events, separate commands, separate
  handlers.
- **New event type:** `MultiplayerMatchRegistered` (also `MultiplayerMatchResultCorrected`
  and `MultiplayerMatchDeleted`). Same tags as their match counterparts but
  prefixed type name.
- **New command classes:** `RegisterMultiplayerMatch`, `CorrectMultiplayerMatch`,
  `DeleteMultiplayerMatch`.
- **New slice views:** a "register multiplayer match" form and edit/delete forms
  for the scoreboard.
- **League mode:** existing `LeagueCreated` event gets a new optional field
  `match_type` defaulting to `"match"`. Existing leagues (without the field)
  default to `"match"` — no migration needed.
- **Game type constant table:** a code constant mapping game_type strings to
  config: ranking direction, min/max players, and an implicit mode.
- **Distribution table:** internal proportional ratios per player count (3-8),
  scaling to the league's stake_percentage.
- **Scoring engine variant:** a new `MultiplayerScoringEngine` alongside the
  existing `ScoringEngine`.
- **Projection updates:** `LeagueMatches`, `Scoreboard`, `Standings`, and the
  `LeagueVersion` TV version counter fold the new event types.
- **Backward compatibility:** all existing leagues, matches, and projections
  continue to work. Existing `LeagueCreated` events have no `match_type` field
  and are treated as match leagues.

## Ubiquitous Language

- **Match** — a head-to-head result (1v1 or 2v2). Players on two fixed sides.
- **Multiplayer match** — an N-player result. Each player enters one score.
  Players are ranked by score; positions determine stakes.
- **League mode** — a league is either a **match league** (contains matches)
  or a **multiplayer league** (contains multiplayer matches).
- **Game type** — a label like "Foosball", "Table Tennis", "Golf". A code
  constant maps each game type to config: ranking direction (ascending /
  descending), minimum players, maximum players.
- **Position** — a player's rank within a multiplayer match (1st, 2nd, 3rd…).
  Tied players share the same position treatment (equal ratio).
- **Stake** — a player pays `current_points * ratio[position] * stake_percentage / 100`
  (integer division). Position 1 pays 0.
- **Pot** — the sum of all stakes. Distributed to the winner(s).

## Predefined Game Type Table

```ruby
GAME_TYPES = {
  "Foosball"    => { ranking: :desc, min_players: 2, max_players: 4 },
  "Table Tennis" => { ranking: :desc, min_players: 2, max_players: 4 },
  "Golf"        => { ranking: :asc, min_players: 1, max_players: 8 },
}.freeze
```

Unknown game types default to: `ranking: :desc, min_players: 2, max_players: 4`.

## Distribution Table (proportional ratios 0..1)

```ruby
DISTRIBUTION = {
  2 => [0.0,  1.0],
  3 => [0.0,  0.375, 0.625],
  4 => [0.0,  0.25,  0.40,  0.35],
  5 => [0.0,  0.18,  0.27,  0.33,  0.22],
  6 => [0.0,  0.15,  0.23,  0.28,  0.22,  0.12],
  7 => [0.0,  0.13,  0.19,  0.23,  0.20,  0.15,  0.10],
  8 => [0.0,  0.11,  0.17,  0.21,  0.19,  0.16,  0.12,  0.04],
}.freeze
```

For a league with stake_percentage `s` and player count `n`:
- Position `i`'s ratio is `DISTRIBUTION[n][i]` (0-indexed, position 1 = index 0).
- Each player at position `i` stakes: `floor(current_points * ratio * s / 100)`.

## Scoring for Multiplayer Matches

1. Players are ranked by score using the game type's `ranking` direction.
2. Positions are determined (ties share the average ratio of their positions).
3. Each player at position `i` (i > 0, i.e. not 1st) stakes:
   `floor(points * DISTRIBUTION[player_count][i] * stake_percentage / 100)`.
4. Pot = sum of all stakes.
5. Winner(s) = player(s) at position 0 (rank 1).
6. Pot is split equally among winners (integer division); remainder distributed
   one point at a time in rank order.
7. If only 1 player, no stakes are taken and no points are awarded (trivial).

### Tied players

Tied players (same score) receive **equal treatment**: they all pay (or gain)
the **average** of the ratios for their shared positions.

Example: 3 players, Alice 10 and Bob 10 tied for 2nd/3rd, Carol 0 is 1st.
- Positions 2 and 3 have ratios 0.375 and 0.625.
- Average = (0.375 + 0.625) / 2 = 0.5.
- Alice and Bob each stake: `floor(points * 0.5 * stake_percentage / 100)`.
- Carol (position 0) stakes 0.
- Pot split between Alice and Bob equally.

## Events

### `MultiplayerMatchRegistered`

```
type: "MultiplayerMatchRegistered"
data: {
  match_id:, league_id:, account_id:,
  player_ids: [id1, id2, ...],
  player_scores: { id1 => score1, id2 => score2, ... },
  registered_by_user_id:
}
tags: ["match:#{match_id}", "league:#{league_id}", "account:#{account_id}",
       *(player_ids.map { |id| "player:#{id}" })]
```

### `MultiplayerMatchResultCorrected`

```
type: "MultiplayerMatchResultCorrected"
data: {
  match_id:, league_id:, account_id:,
  player_scores: { id1 => score1, id2 => score2, ... },
  corrected_by_user_id:
}
tags: ["match:#{match_id}", "league:#{league_id}", "account:#{account_id}"]
```

### `MultiplayerMatchDeleted`

```
type: "MultiplayerMatchDeleted"
data: {
  match_id:, league_id:, account_id:,
  deleted_by_user_id:
}
tags: ["match:#{match_id}", "league:#{league_id}", "account:#{account_id}"]
```

## Projection Updates

### `Leagues::League`

Add `match_type` to the `Summary` struct and the `created` builder. Default
to `"match"` when the field is absent from the event data (for existing events
that lack it).

```ruby
Summary = Data.define(:id, :account_id, :name, :game_type, :starting_points,
                      :stake_percentage, :status, :match_type) do
  def open? = status == :open
  def closed? = status == :closed
  def match_league? = match_type == "match"
  def multiplayer_league? = match_type == "multiplayer"
end
```

In the `created` method:
```ruby
match_type: event.data.fetch(:match_type, "match")
```

### `Leagues::CreateLeague`

Add a `match_type` parameter (default `"match"`). Pass it to `Events.league_created`.

### `Leagues::Events`

Update `league_created` to accept and include `match_type:` (with default
`"match"`).

### `Scoreboards::LeagueMatches`

Add `"MultiplayerMatchRegistered"`, `"MultiplayerMatchResultCorrected"`,
`"MultiplayerMatchDeleted"` to the query event types. Build a `Match` value
object for multiplayer events (with `player_ids`, `player_scores` instead of
home/away).

### `Scoreboards::LeagueVersion`

Add the three new event types to the `EVENT_TYPES` constant.

### `Scoreboards::Match` / `Scoreboards::MultiplayerMatch`

Two separate value objects:
- `Scoreboards::Match` — for `MatchRegistered` events (home/away sides).
- `Scoreboards::MultiplayerMatch` — for `MultiplayerMatchRegistered` events
  (player_ids, player_scores). New struct, no shared base with `Match`.

The `LeagueMatches` projection returns an array of either type. Consumers
(pattern-match on class) handle each appropriately.

### `Scoreboards::Standings`

Accept a `mode: :match | :multiplayer` and a scoring engine appropriate for
the mode. For multiplayer, use the new `MultiplayerScoringEngine`.

### `Scoreboards::ScoringEngine` (new: `MultiplayerScoringEngine`)

```ruby
module Scoreboards
  class MultiplayerScoringEngine
    def initialize(stake_percentage:, game_type:)
      @stake_percentage = stake_percentage
      @game_type = game_type
    end

    # players: [{id:, score:}]
    # Returns { player_id => points_after }
    def settle(points, players)
      ranked = rank(players)
      positions = compute_positions(ranked)
      stakes = compute_stakes(ranked, positions, points)
      pot = stakes.values.sum
      award(points, stakes, pot, ranked)
    end

    private

    def rank(players)
      game_type_config = GameType.find(@game_type)
      direction = game_type_config.ranking
      # Sort by score in the specified direction
      players.sort_by { |p| p[:score] }
             .reverse_if(direction == :desc)
             .map.with_index { |p, i| p.merge(position: i) }
    end

    def compute_positions(ranked)
      # Handle ties: tied players share average ratio
      # Returns { player_id => ratio }
    end

    def compute_stakes(ranked, positions, points)
      # { player_id => stake_amount }
    end
  end
end
```

### `Scoreboards::RecentMatches`

Build display lines for multiplayer matches. The `line` method pattern-matches
on the match class: for `Match` use the existing "A beats B 21-8" format;
for `MultiplayerMatch` use a ranked format like "Alice (10), Bob (5), Carol (0)"
sorted by ranking order (ascending or descending per game type).

### `Scoreboards::Scoreboard`

Pass the league's `match_type` to the standings computation.

## Command Changes

### `Matches::RegisterMultiplayerMatch`

New command class. Parameters:
```ruby
RegisterMultiplayerMatch.call(
  league_id:, account_id:, user_id:,
  player_ids: [id1, id2, ...],
  player_scores: { id1 => score1, ... }
)
```

Flow:
1. Validate input: `player_ids` is non-empty, within game type's min/max, all
   distinct, scores are integers, no player id appears twice.
2. Decision: member check, league existence, league open, all players members.
3. Append `MultiplayerMatchRegistered` event.

### `Matches::CorrectMultiplayerMatch`

New command class. Parameters:
```ruby
CorrectMultiplayerMatch.call(
  match_id:, league_id:, account_id:, user_id:,
  player_scores: { id1 => score1, ... }
)
```

Uses `MultiplayerMatchDetails` to find the match and verify the actor is a
player. Validates all scores are integers. Appends
`MultiplayerMatchResultCorrected`.

### `Matches::DeleteMultiplayerMatch`

Reuse `Matches::DeleteMatch` logic but look up via
`MultiplayerMatchDetails`. Appends `MultiplayerMatchDeleted`.

The edit and delete UI shares the same controller action (a single `edit`
and `update` route for both match types). The controller reads the league's
`match_type` from `League.find` and renders the appropriate form layout.

## Web Changes

### `Matches::MatchesController`

The `#new` and `#create` actions branch based on league mode:
- Match league → existing form (home/away sides)
- Multiplayer league → new form (player score table)

### Forms

**New form:** `app/slices/matches/views/matches/new_multiplayer.html.erb`

A table of rows: one per player selected from the account members list.
Each row has a player select (dropdown) and a score input.

**Edit form:** Extend the existing edit form to handle multiplayer. Check the
league mode and render the appropriate input layout.

### Scoreboard Page

Add "Register multiplayer match" link for multiplayer leagues. Keep "Register
match" for match leagues.

## Event Store: LeagueCreated change

The `LeagueCreated` event data gets one new field: `match_type` with default
`"match"`. Existing events have no such field; the read model falls back to
`"match"` via `fetch(:match_type, "match")`.

This means:
- Existing leagues: `match_type` is `"match"` (implicit default).
- New leagues created as match type: `match_type: "match"` (explicit in event).
- New leagues created as multiplayer: `match_type: "multiplayer"` (explicit in event).

## TV Dashboard

The TV version counter must count the new event types. The TV dashboard's
recent matches section renders multiplayer match lines. The standings and
spotlights work the same — they're derived from the re-folded standings.

## Impact on Existing Tests

- All existing features continue to pass unchanged (existing leagues default
  to `match_type: "match"`).
- New features for multiplayer matches (separate feature files).
- Unit specs: new specs for `RegisterMultiplayerMatch`, `CorrectMultiplayerMatch`,
  `MultiplayerScoringEngine`, `MultiplayerMatchDetails`.
- Updated specs: `RegisterMatch` (unchanged), `LeagueState` projection,
  `LeagueMatches` projection, `Standings`, `RecentMatches`.

## Handoff Summary

New files:
- `features/matches/register_multiplayer_match.feature`
- `features/matches/correct_multiplayer_match.feature`
- `features/matches/delete_multiplayer_match.feature`
- `app/slices/matches/domain/register_multiplayer_match.rb`
- `app/slices/matches/domain/correct_multiplayer_match.rb`
- `app/slices/matches/domain/multiplayer_match_details.rb`
- `app/slices/matches/domain/multiplayer_match_decision.rb` (or extend MatchDecision)
- `app/slices/matches/domain/game_type.rb`
- `app/slices/matches/domain/distribution.rb`
- `app/slices/matches/domain/multiplayer_match_score.rb` (integer validation,
  allows negative scores; distinct from MatchScore which enforces non-negative)
- `app/slices/matches/domain/events.rb` (update: add 3 constructors)
- `app/slices/scoreboards/domain/multiplayer_scoring_engine.rb`
- `app/slices/scoreboards/domain/multiplayer_match.rb` (new: separate struct)

Modified files:
- `app/slices/leagues/domain/events.rb` (add `match_type:` to `league_created`)
- `app/slices/leagues/domain/league.rb` (add `match_type` to `Summary`)
- `app/slices/leagues/domain/create_league.rb` (add `match_type` param)
- `app/slices/matches/domain/events.rb` (add 3 new event constructors)
- `app/slices/matches/domain/match_details.rb` (fold multiplayer events)
- `app/slices/matches/domain/match_decision.rb` (unchanged — shared)
- `app/slices/matches/web/matches_controller.rb` (branch on league mode)
- `app/slices/matches/web/matches_controller.rb` (`load_form` reads `match_type`)
- `app/slices/scoreboards/domain/league_matches.rb` (fold multiplayer events)
- `app/slices/scoreboards/domain/league_version.rb` (add event types)
- `app/slices/scoreboards/domain/scoreboard.rb` (pass mode to standings)
- `app/slices/scoreboards/domain/standings.rb` (multiplayer scoring path)
- `app/slices/scoreboards/domain/scoring_engine.rb` (unchanged — reference)
- `app/slices/scoreboards/domain/recent_matches.rb` (format multiplayer lines)
- `app/slices/scoreboards/domain/match.rb` (extend to multiplayer shape)
- `app/slices/statistics/domain/match.rb` (extend to multiplayer shape)
- `app/slices/statistics/domain/multiplayer_match.rb` (new: separate struct)
- `app/slices/statistics/domain/scoring_engine.rb` (new engine — refactor to
  extract common scoring logic or keep separate)
- `app/slices/statistics/domain/stake_ledger.rb` (use correct engine per mode)
- `app/slices/statistics/domain/match_history.rb` (format multiplayer lines)
- `app/slices/statistics/domain/player_page.rb` (pass mode)
- `app/slices/statistics/domain/form.rb` (handle multiplayer results)
- `app/slices/statistics/domain/head_to_head.rb` (handle multiplayer opponents)
- `app/slices/statistics/domain/membership.rb` (unchanged)
- Various view files for the new form and updated scoreboard links.
- `docs/DOMAIN.md` (add events table row, update matching section, add
  multiplayer match description, update TV version event list)
- `docs/ARCHITECTURE.md` (update event table, add new event types)

After handoff approval: commit and notify coder.