Feature: Register a multiplayer match
  In a multiplayer league, participants each enter a score (integer, can be
  negative). Participants are ranked by score in the order the game type
  specifies (ascending or descending). Each position (except 1st) pays a
  percentage of its current points based on the internal distribution table,
  scaled by the league's stake_percentage. The pot is the sum of all stakes
  and is distributed to the winner(s) with integer division; the remainder is
  handed out one point at a time to winners in rank order.

  A multiplayer match is played by a subset of the account's members: the
  registrar picks who took part (see "Multiplayer match registration form").
  How many may take part is fixed by the game type — Foosball and Table
  Tennis take 2 to 4 players, Golf takes 1 to 8, and a game type nobody has
  configured takes 2 to 4. Where the game type allows a single player, such a
  match is accepted but is a no-op: the player stakes nothing and gains
  nothing. Every player must be a member of the account.

  Rejection order is fixed so a mistake reports its own cause: players must
  be distinct before the count is judged, so picking the same player twice is
  reported as a duplicate rather than as a wrong number of players.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Carol" is a registered user with email "carol@example.com" and password "secret123"
    And "Dave" is a registered user with email "dave@example.com" and password "secret123"
    And "Eve" is a registered user with email "eve@example.com" and password "secret123"
    And "Alice" owns the "Office" account
    And "Bob" is a member of the "Office" account
    And "Carol" is a member of the "Office" account
    And "Dave" is a member of the "Office" account
    And "Eve" is a member of the "Office" account
    And the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%

  # register_multiplayer_match-1
  Scenario: Ranking direction depends on game type
    # A game with ascending ranking: lowest score is 1st place
    # Golf: basis-points for 3 players: [0, 3750, 6250]
    # Bob: score 0,  1st place (0 basis-points, 0 stake)
    # Alice: score 5, 2nd place (3750 * 10 * 1000 / 10_000_000 = 37)
    # Carol: score 10, 3rd place (6250 * 10 * 1000 / 10_000_000 = 62)
    # Pot = 37 + 62 = 99; Bob (1st by rank) gets 99
    # Bob: 1000 + 99 = 1099, Alice: 1000 - 37 = 963, Carol: 1000 - 62 = 938
    When the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" registers a multiplayer match in "Golf Cup" where "Bob" scores 0, "Alice" scores 5, and "Carol" scores 10
    Then "Bob" has 1099 points in "Golf Cup"
    And "Alice" has 963 points in "Golf Cup"
    And "Carol" has 938 points in "Golf Cup"

  # register_multiplayer_match-2
  Scenario: Descending ranking: highest score is 1st place
    # Foosball with multiplayer mode: highest score wins
    # basis-points for 3 players: [0, 3750, 6250]
    # Alice: score 21, 1st (0 basis-points, 0 stake)
    # Bob: score 15, 2nd (3750 * 10 * 1000 / 10_000_000 = 37)
    # Carol: score 8, 3rd (6250 * 10 * 1000 / 10_000_000 = 62)
    # Pot = 37 + 62 = 99; Alice gets 99 -> 1099
    When the "Office" account has an open league "Foosball Open" for "Foosball" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" registers a multiplayer match in "Foosball Open" where "Alice" scores 21, "Bob" scores 15, and "Carol" scores 8
    Then "Alice" has 1099 points in "Foosball Open"
    And "Bob" has 963 points in "Foosball Open"
    And "Carol" has 938 points in "Foosball Open"

  # register_multiplayer_match-3
  Scenario: Single player match — no stakes, no gains
    # Golf allows a single player; the match is a legal no-op.
    When the "Office" account has an open league "Solo Golf" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" registers a multiplayer match in "Solo Golf" where "Alice" scores 0
    Then "Alice" has 1000 points in "Solo Golf"

  # register_multiplayer_match-4
  Scenario: Two players
    # basis-points for 2 players: [0, 10000]
    # 1st pays 0%, 2nd pays 100% of stake_percentage
    # Alice: 10 (1st), Bob: 5 (2nd)
    # Bob stakes: 10000 * 10 * 1000 / 10_000_000 = 100; pot = 100; Alice gets 100
    # Alice: 1100, Bob: 900
    When the "Office" account has an open league "Head to Head" for "Foosball" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" registers a multiplayer match in "Head to Head" where "Alice" scores 10, "Bob" scores 5
    Then "Alice" has 1100 points in "Head to Head"
    And "Bob" has 900 points in "Head to Head"

  # register_multiplayer_match-5
  Scenario: Ties are treated equally
    # basis-points for 3 players: [0, 3750, 6250]
    # Ascending ranking: Carol 0 (1st), Alice 10 & Bob 10 (tied 2nd/3rd)
    # Tied players share average basis-points: (3750 + 6250) / 2 = 5000
    # Each stakes: 1000 * 5000 * 10 / 1_000_000 = 50
    # Carol (1st) stakes 0. Pot = 50 + 50 = 100; Carol is sole winner.
    # Carol: 1000 + 100 = 1100, Alice: 1000 - 50 = 950, Bob: 1000 - 50 = 950
    When the "Office" account has an open league "Tied Golf" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" registers a multiplayer match in "Tied Golf" where "Carol" scores 0, "Alice" scores 10, and "Bob" scores 10
    Then "Carol" has 1100 points in "Tied Golf"
    And "Alice" has 950 points in "Tied Golf"
    And "Bob" has 950 points in "Tied Golf"

  # register_multiplayer_match-6
  Scenario: Scores can be negative
    # Golf: ascending ranking. Lowest score is 1st.
    # basis-points for 3 players: [0, 3750, 6250]
    # Bob: score -50 (1st), Alice: 10 (2nd), Carol: 30 (3rd)
    # Alice stakes: 3750 * 10 * 1000 / 10_000_000 = 37
    # Carol stakes: 6250 * 10 * 1000 / 10_000_000 = 62
    # Pot = 37 + 62 = 99; Bob gets 99 -> 1099
    When the "Office" account has an open league "Winter Golf" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" registers a multiplayer match in "Winter Golf" where "Bob" scores -50, "Alice" scores 10, and "Carol" scores 30
    Then "Bob" has 1099 points in "Winter Golf"
    And "Alice" has 963 points in "Winter Golf"
    And "Carol" has 938 points in "Winter Golf"

  # register_multiplayer_match-7
  Scenario: All players must be account members
    Given "Frank" is a registered user with email "frank@example.com" and password "secret123"
    When "Alice" attempts to register a multiplayer match in "Golf Cup" where "Alice" scores 10 and "Frank" scores 5
    Then the registration is rejected because "all players must be members of the account"

  # register_multiplayer_match-8
  Scenario: A non-member cannot register a multiplayer match
    Given "Frank" is a registered user with email "frank@example.com" and password "secret123"
    When "Frank" attempts to register a multiplayer match in "Golf Cup" where "Frank" scores 10 and "Alice" scores 5
    Then the registration is rejected because "only members can register matches"

  # register_multiplayer_match-9
  Scenario: Cannot register a multiplayer match in a closed league
    Given the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" has already registered a multiplayer match in "Golf Cup" where "Bob" scores 0, "Alice" scores 5, and "Carol" scores 10
    And "Alice" closes the "Golf Cup" league
    When "Alice" attempts to register a multiplayer match in "Golf Cup" where "Dave" scores 10 and "Eve" scores 5
    Then the registration is rejected because "the league is closed"

  # register_multiplayer_match-10
  Scenario Outline: The game type fixes how many players a match takes
    Given the "Office" account has an open league "Club Night" for "<game type>" as a multiplayer league with starting points 1000 and stake 10%
    When "Alice" attempts to register a multiplayer match in "Club Night" with <players> players
    Then the registration is rejected because "a <game type> match needs <min> to <max> players"

    Examples:
      | game type | players | min | max |
      | Foosball  | 1       | 2   | 4   |
      | Foosball  | 5       | 2   | 4   |
      | Golf      | 0       | 1   | 8   |

  # register_multiplayer_match-11
  Scenario: Score input is validated — non-integer scores are rejected
    When the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" attempts to register a multiplayer match in "Golf Cup" where "Alice" scores 10.5 and "Bob" scores 5
    Then the registration is rejected because "scores must be integers"

  # register_multiplayer_match-12
  Scenario: Players cannot be duplicated in a match
    When the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" attempts to register a multiplayer match in "Golf Cup" where "Alice" scores 10 and "Alice" scores 5
    Then the registration is rejected because "players must be distinct"
