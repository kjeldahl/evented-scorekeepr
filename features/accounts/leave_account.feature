Feature: Leave account
  Any member — a player or the account's owner — can leave an account. The
  departed member loses access and disappears from the members list, but
  history is untouched: their registered matches and standings remain. A
  departed member can be invited back in.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Alice" owns the "Office" account
    And "Bob" is a member of the "Office" account

  Scenario: A player leaves the account
    When "Bob" leaves the "Office" account
    Then "Bob" is not a member of the "Office" account
    And "Bob" cannot see the "Office" account
    And "Alice" does not see the member "Bob" in the "Office" account

  Scenario: The owner can leave the account too
    When "Alice" leaves the "Office" account
    Then "Alice" is not a member of the "Office" account
    And "Alice" cannot see the "Office" account
    And "Bob" can see the "Office" account

  Scenario: A departed member can be invited back in
    Given "Bob" leaves the "Office" account
    And "Alice" invites "bob@example.com" to the "Office" account
    When "Bob" accepts the invitation to the "Office" account
    Then "Bob" is a member of the "Office" account

  Scenario: Leaving does not change history
    Given the "Office" account has an open league "Foosball Spring" for "Foosball" with starting points 1000 and stake 10%
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    When "Bob" leaves the "Office" account
    Then the "Foosball Spring" scoreboard shows:
      | rank | player | points | played | won | lost | streak |
      | 1    | Alice  | 1100   | 1      | 1   | 0    | W1     |
      | 2    | Bob    | 900    | 1      | 0   | 1    | L1     |

  Scenario: A departed member cannot be put on a match
    Given the "Office" account has an open league "Foosball Spring" for "Foosball" with starting points 1000 and stake 10%
    And "Bob" leaves the "Office" account
    When "Alice" attempts to register a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    Then the match is rejected because "all players must be members of the account"
