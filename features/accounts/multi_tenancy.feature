Feature: Multi-tenancy
  A user registers once and can be a member of several accounts, playing in
  leagues in each. Accounts are strict tenants: data from one account is
  never visible in another, and a non-member who tries to reach an account,
  a league or a scoreboard is refused.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Carol" is a registered user with email "carol@example.com" and password "secret123"
    And "Alice" owns the "Office" account
    And "Carol" owns the "Family" account
    And "Bob" is a member of the "Office" account
    And "Bob" is a member of the "Family" account
    And the "Office" account has an open league "Office Foosball" for "Foosball" with starting points 1000 and stake 10%
    And the "Family" account has an open league "Family Foosball" for "Foosball" with starting points 1000 and stake 10%

  Scenario: A user plays in leagues in several accounts with independent points
    # Office Foosball: Alice stakes 10% of 1000 = 100 -> Bob 1100, Alice 900
    # Family Foosball: Bob stakes 10% of 1000 = 100 -> Carol 1100, Bob 900
    When "Bob" registers a match in "Office Foosball" where "Bob" beats "Alice" 21-8
    And "Bob" registers a match in "Family Foosball" where "Carol" beats "Bob" 21-12
    Then "Bob" has 1100 points in "Office Foosball"
    And "Bob" has 900 points in "Family Foosball"

  Scenario: Scoreboards only show players from their own account
    When "Bob" registers a match in "Office Foosball" where "Bob" beats "Alice" 21-8
    And "Bob" registers a match in "Family Foosball" where "Carol" beats "Bob" 21-12
    Then the "Office Foosball" scoreboard shows:
      | rank | player | points | played | won | lost | streak |
      | 1    | Bob    | 1100   | 1      | 1   | 0    | W1     |
      | 2    | Alice  | 900    | 1      | 0   | 1    | L1     |
    And the "Family Foosball" scoreboard shows:
      | rank | player | points | played | won | lost | streak |
      | 1    | Carol  | 1100   | 1      | 1   | 0    | W1     |
      | 2    | Bob    | 900    | 1      | 0   | 1    | L1     |
    And "Carol" does not appear on the "Office Foosball" scoreboard
    And "Alice" does not appear on the "Family Foosball" scoreboard

  Scenario: A non-member is refused access to an account, its leagues and its scoreboards
    Given "Bob" registers a match in "Office Foosball" where "Bob" beats "Alice" 21-8
    Then "Carol" cannot see the "Office" account
    And "Carol" cannot see the "Office Foosball" league
    And "Carol" cannot see the scoreboard of "Office Foosball"

  Scenario: Membership of one account grants nothing in another
    Then "Alice" is not a member of the "Family" account
    And "Alice" cannot see the "Family" account
    And "Alice" cannot see the "Family Foosball" league
    And "Alice" cannot see the scoreboard of "Family Foosball"
