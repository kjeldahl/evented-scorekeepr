Feature: Correct a multiplayer match result
  In a multiplayer league, any player who took part in a match can correct
  its scores while the league is open. Only the scores change; the
  participants are fixed. A correction is a MatchResultCorrected event
  folded onto its MatchRegistered, so the whole league re-folds in order
  and every later standing re-derives from the corrected scores.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Carol" is a registered user with email "carol@example.com" and password "secret123"
    And "Alice" owns the "Office" account
    And "Bob" is a member of the "Office" account
    And "Carol" is a member of the "Office" account

  Scenario: A participant corrects their scores
    Given the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" has registered a multiplayer match in "Golf Cup" where "Bob" scores 0, "Alice" scores 5, and "Carol" scores 10
    When "Alice" corrects the match where "Bob" scores 2, "Alice" scores 7, and "Carol" scores 10
    Then the correction is accepted

  Scenario: Only players in the match can correct it
    Given the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Dave" is a registered user with email "dave@example.com" and password "secret123"
    And "Dave" is a member of the "Office" account
    And "Alice" has registered a multiplayer match in "Golf Cup" where "Bob" scores 0, "Alice" scores 5, and "Carol" scores 10
    When "Dave" attempts to correct the match where "Bob" scores 2 and "Alice" scores 7
    Then the correction is rejected because "only players in the match can correct it"

  Scenario: Cannot correct a match in a closed league
    Given the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" has registered a multiplayer match in "Golf Cup" where "Bob" scores 0, "Alice" scores 5, and "Carol" scores 10
    And "Alice" closes the "Golf Cup" league
    When "Alice" attempts to correct the match where "Bob" scores 2 and "Alice" scores 7
    Then the correction is rejected because "the league is closed"

  Scenario: Corrected scores are validated
    Given the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" has registered a multiplayer match in "Golf Cup" where "Bob" scores 0, "Alice" scores 5, and "Carol" scores 10
    When "Alice" attempts to correct the match where "Bob" scores 2 and "Alice" scores 7.5
    Then the correction is rejected because "scores must be integers"

  Scenario: A corrected match that flips positions changes the standings
    # Original: Alice 0 (1st), Bob 5 (2nd), Carol 10 (3rd)
    # Bob stakes: floor(1000 * 0.375 * 10 / 100) = 37, Carol stakes: floor(1000 * 0.625 * 10 / 100) = 62
    # Pot = 37 + 62 = 99. Alice gets 99 -> 1099, Bob 963, Carol 938.
    # Corrected: Bob 0 (1st), Alice 5 (2nd), Carol 10 (3rd)
    # Alice (2nd) stakes 37, Carol (3rd) stakes 62, pot = 99. Bob gets 99 -> 1099.
    # Alice 1000 - 37 = 963, Carol 1000 - 62 = 938. Bob jumps from 963 to 1099.
    Given the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" has registered a multiplayer match in "Golf Cup" where "Alice" scores 0, "Bob" scores 5, and "Carol" scores 10
    And "Alice" corrects the match where "Bob" scores 0, "Alice" scores 5, and "Carol" scores 10
    Then "Bob" has 1099 points in "Golf Cup"
    And "Alice" has 963 points in "Golf Cup"
    And "Carol" has 938 points in "Golf Cup"

  Scenario: Tied players share stakes equally
    # Ratios for 3 players: [0, 0.375, 0.625]
    # Ascending: Carol 0 (1st), Alice 10 & Bob 10 tied (positions 1, 2 → avg ratio 0.5)
    # Alice stakes: floor(1000 * 0.5 * 10 / 100) = 50, Bob stakes: 50
    # Carol stakes 0. Pot = 100. Split 50 each.
    # Carol: 1050, Alice: 950, Bob: 950
    Given the "Office" account has an open league "Tied Golf" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" has registered a multiplayer match in "Tied Golf" where "Carol" scores 0, "Alice" scores 10, and "Bob" scores 10
    Then "Carol" has 1050 points in "Tied Golf"
    And "Alice" has 950 points in "Tied Golf"
    And "Bob" has 950 points in "Tied Golf"