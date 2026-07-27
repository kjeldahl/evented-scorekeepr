Feature: Register a multiplayer match
  In a multiplayer league, participants each enter a score (integer, can be
  negative). Participants are ranked by score in the order the game type
  specifies (ascending or descending). Each position (except 1st) pays a
  percentage of its current points based on the internal distribution table,
  scaled by the league's stake_percentage. The pot is the sum of all stakes
  and is distributed to the winner(s) with integer division; the remainder is
  handed out one point at a time to winners in rank order.

  A multiplayer match has 1 or more players, all of whom must be members of
  the account. A match with a single player is accepted (the player stakes
  nothing and gains nothing).

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

  Scenario: Ranking direction depends on game type
    # A game with ascending ranking: lowest score is 1st place
    # Golf: 1st place (lowest score) pays 0%; 2nd pays ratio[2]*stake%; 3rd pays ratio[3]*stake%
    # Stake 10%, ratios for 3 players: [0, 0.375, 0.625]
    # Bob: score 0,  1st place (0% stake)
    # Alice: score 5, 2nd place (floor(1000 * 0.375 * 10 / 100) = 37)
    # Carol: score 10, 3rd place (floor(1000 * 0.625 * 10 / 100) = 62)
    # Pot = 37 + 62 = 99; Alice (only winner) gets 99
    # Alice: 1000 + 99 = 1099, Bob: 1000, Carol: 1000 - 62 = 938
    When the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" registers a multiplayer match in "Golf Cup" where "Bob" scores 0, "Alice" scores 5, and "Carol" scores 10
    Then "Bob" has 1000 points in "Golf Cup"
    And "Alice" has 1099 points in "Golf Cup"
    And "Carol" has 938 points in "Golf Cup"

  Scenario: Descending ranking: highest score is 1st place
    # Foosball with multiplayer mode: highest score wins
    # Stake 10%, ratios for 3 players: [0, 0.375, 0.625]
    # Alice: score 21, 1st (0% stake)
    # Bob: score 15, 2nd (floor(1000 * 0.375 * 10 / 100) = 37)
    # Carol: score 8, 3rd (floor(1000 * 0.625 * 10 / 100) = 62)
    # Pot = 37 + 62 = 99; Alice gets 99 -> 1099
    When the "Office" account has an open league "Foosball Open" for "Foosball" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" registers a multiplayer match in "Foosball Open" where "Alice" scores 21, "Bob" scores 15, and "Carol" scores 8
    Then "Alice" has 1099 points in "Foosball Open"
    And "Bob" has 963 points in "Foosball Open"
    And "Carol" has 938 points in "Foosball Open"

  Scenario: Single player match — no stakes, no gains
    When the "Office" account has an open league "Solo Golf" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" registers a multiplayer match in "Solo Golf" where "Alice" scores 0
    Then "Alice" has 1000 points in "Solo Golf"

  Scenario: Two players
    # Ratios for 2 players: [0, 1.0]
    # 1st pays 0%, 2nd pays 100% of stake_percentage
    # Alice: 10 (1st), Bob: 5 (2nd)
    # Bob stakes 10% of 1000 = 100; pot = 100; Alice gets 100
    # Alice: 1100, Bob: 900
    When the "Office" account has an open league "Head to Head" for "Foosball" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" registers a multiplayer match in "Head to Head" where "Alice" scores 10, "Bob" scores 5
    Then "Alice" has 1100 points in "Head to Head"
    And "Bob" has 900 points in "Head to Head"

  Scenario: Ties are treated equally
    # Ratios for 3 players: [0, 0.375, 0.625]
    # Ascending ranking: Carol 0 (1st), Alice 10 & Bob 10 (tied 2nd/3rd)
    # Tied players get equal treatment: average ratio of their positions
    # = (0.375 + 0.625) / 2 = 0.5. Each stakes 5% of 1000 = 50.
    # Carol (1st) stakes 0. Pot = 100; split evenly: 50 each.
    # Carol: 1000 + 50 = 1050, Alice: 1000 - 50 = 950, Bob: 1000 - 50 = 950
    When the "Office" account has an open league "Tied Golf" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" registers a multiplayer match in "Tied Golf" where "Carol" scores 0, "Alice" scores 10, and "Bob" scores 10
    Then "Carol" has 1050 points in "Tied Golf"
    And "Alice" has 950 points in "Tied Golf"
    And "Bob" has 950 points in "Tied Golf"

  Scenario: Scores can be negative
    # Golf: ascending ranking. Lowest score is 1st.
    # Ratios for 3 players: [0, 0.375, 0.625]
    # Bob: score -50 (1st), Alice: 10 (2nd), Carol: 30 (3rd)
    # Alice stakes floor(1000 * 0.375 * 10 / 100) = 37; Carol stakes 62; pot = 99
    # Alice gets 99 -> 1099
    When the "Office" account has an open league "Winter Golf" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" registers a multiplayer match in "Winter Golf" where "Bob" scores -50, "Alice" scores 10, and "Carol" scores 30
    Then "Bob" has 1000 points in "Winter Golf"
    And "Alice" has 1099 points in "Winter Golf"
    And "Carol" has 938 points in "Winter Golf"

  Scenario: All players must be account members
    Given "Frank" is a registered user with email "frank@example.com" and password "secret123"
    When "Alice" attempts to register a multiplayer match in "Golf Cup" where "Alice" scores 10 and "Frank" scores 5
    Then the registration is rejected because "all players must be members of the account"

  Scenario: A non-member cannot register a multiplayer match
    Given "Frank" is a registered user with email "frank@example.com" and password "secret123"
    When "Frank" attempts to register a multiplayer match in "Golf Cup" where "Frank" scores 10 and "Alice" scores 5
    Then the registration is rejected because "only members can register matches"

  Scenario: Cannot register a multiplayer match in a closed league
    Given the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" has already registered a multiplayer match in "Golf Cup" where "Bob" scores 0, "Alice" scores 5, and "Carol" scores 10
    And "Alice" closes the "Golf Cup" league
    When "Alice" attempts to register a multiplayer match in "Golf Cup" where "Dave" scores 10 and "Eve" scores 5
    Then the registration is rejected because "the league is closed"

  Scenario: Only scores in the range allowed by game type are accepted
    When the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" attempts to register a multiplayer match in "Golf Cup" with fewer than 1 players
    Then the registration is rejected because "at least 1 participant is required"

  Scenario: Score input is validated — non-integer scores are rejected
    When the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" attempts to register a multiplayer match in "Golf Cup" where "Alice" scores 10.5 and "Bob" scores 5
    Then the registration is rejected because "scores must be integers"

  Scenario: Players cannot be duplicated in a match
    When the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" attempts to register a multiplayer match in "Golf Cup" where "Alice" scores 10 and "Alice" scores 5
    Then the registration is rejected because "players must be distinct"