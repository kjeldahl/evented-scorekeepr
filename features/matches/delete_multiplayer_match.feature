Feature: Delete a multiplayer match result
  Any player who took part in a match can delete it while the league is open.
  A deletion is a MatchDeleted event folded onto its MatchRegistered, so the
  whole league re-folds in order as if the match had never been registered.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Carol" is a registered user with email "carol@example.com" and password "secret123"
    And "Alice" owns the "Office" account
    And "Bob" is a member of the "Office" account
    And "Carol" is a member of the "Office" account

  Scenario: A participant deletes the match
    Given the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" has registered a multiplayer match in "Golf Cup" where "Bob" scores 0, "Alice" scores 5, and "Carol" scores 10
    When "Alice" deletes the match
    Then the deletion is accepted
    And "Alice" is not listed in the "Golf Cup" standings
    And "Bob" is not listed in the "Golf Cup" standings
    And "Carol" is not listed in the "Golf Cup" standings

  Scenario: Only players in the match can delete it
    Given the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Dave" is a registered user with email "dave@example.com" and password "secret123"
    And "Dave" is a member of the "Office" account
    And "Alice" has registered a multiplayer match in "Golf Cup" where "Bob" scores 0, "Alice" scores 5, and "Carol" scores 10
    When "Dave" attempts to delete the match
    Then the deletion is rejected because "only players in the match can delete it"

  Scenario: Cannot delete a match in a closed league
    Given the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" has registered a multiplayer match in "Golf Cup" where "Bob" scores 0, "Alice" scores 5, and "Carol" scores 10
    And "Alice" closes the "Golf Cup" league
    When "Alice" attempts to delete the match
    Then the deletion is rejected because "the league is closed"

  Scenario: Deleting a match re-derives later standings
    # After deleting match 1, all three are at starting points (1000).
    # Match 2: Bob 0 (1st), Alice 5 (2nd), Carol 10 (3rd)
    # Alice stakes floor(1000 * 0.0375) = 37, Carol stakes floor(1000 * 0.625) = 62, pot = 99.
    # Bob gets 99 -> 1099, Alice 1000 - 37 = 963, Carol 1000 - 62 = 938.
    Given the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" has registered a multiplayer match in "Golf Cup" where "Bob" scores 0, "Alice" scores 5, and "Carol" scores 10
    And "Alice" has registered a multiplayer match in "Golf Cup" where "Bob" scores 0, "Alice" scores 5, and "Carol" scores 10
    When "Alice" deletes the first match
    Then "Bob" has 1099 points in "Golf Cup"
    And "Alice" has 963 points in "Golf Cup"
    And "Carol" has 938 points in "Golf Cup"

  Scenario: Deleting a match where a player only participated removes them from standings
    Given the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%
    And "Alice" has registered a multiplayer match in "Golf Cup" where "Bob" scores 0, "Alice" scores 5, and "Carol" scores 10
    When "Alice" deletes the match
    Then "Alice" is not listed in the "Golf Cup" standings
    And "Bob" is not listed in the "Golf Cup" standings
    And "Carol" is not listed in the "Golf Cup" standings