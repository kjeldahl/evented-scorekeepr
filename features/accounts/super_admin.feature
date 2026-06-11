Feature: Super admin
  A super admin is a user who can view every account without being a member
  of any of them. This is a deliberate, narrow exception to the invariant
  that only account members can view an account, its leagues and
  scoreboards — and it is read-only: being a super admin grants no
  membership and no write privileges. A super admin sees exactly what
  members see (members, leagues, scoreboards, player statistics), but is
  never listed as a member, cannot be put on a match, and cannot register
  matches in accounts they are not a member of. How a user becomes a super
  admin is out of scope here; "is a super admin" is the contract. A super
  admin who is also an ordinary member of some account behaves like any
  other member there.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Carol" is a registered user with email "carol@example.com" and password "secret123"
    And "Root" is a registered user with email "root@example.com" and password "secret123"
    And "Root" is a super admin
    And "Alice" owns the "Office" account
    And "Carol" owns the "Family" account
    And "Bob" is a member of the "Office" account
    And the "Office" account has an open league "Office Foosball" for "Foosball" with starting points 1000 and stake 10%
    And the "Family" account has an open league "Family Foosball" for "Foosball" with starting points 1000 and stake 10%

  Scenario: A super admin can view every account, its leagues and scoreboards without membership
    Then "Root" is not a member of the "Office" account
    And "Root" can see the "Office" account
    And "Root" can see the "Office Foosball" league
    And "Root" can see the scoreboard of "Office Foosball"
    And "Root" is not a member of the "Family" account
    And "Root" can see the "Family" account
    And "Root" can see the "Family Foosball" league
    And "Root" can see the scoreboard of "Family Foosball"

  Scenario: An ordinary user is still refused access to accounts they are not a member of
    Then "Bob" cannot see the "Family" account
    And "Bob" cannot see the "Family Foosball" league
    And "Bob" cannot see the scoreboard of "Family Foosball"

  Scenario: A super admin sees an account's members without appearing among them
    Then "Root" sees the member "Alice" in the "Office" account
    And "Root" sees the member "Bob" in the "Office" account
    And "Alice" does not see the member "Root" in the "Office" account

  Scenario: A super admin sees the same scoreboard and player statistics that members see
    # Bob stakes 10% of 1000 = 100 -> Alice 1100, Bob 900
    Given "Alice" registers a match in "Office Foosball" where "Alice" beats "Bob" 21-8
    When "Root" opens "Alice"'s statistics page in "Office Foosball"
    Then the player page shows 1100 points, rank 1 and 1 matches played
    And "Root" does not appear on the "Office Foosball" scoreboard

  Scenario: Being a super admin grants no right to register matches
    When "Root" attempts to register a match in "Office Foosball" where "Alice" beats "Bob" 21-8
    Then the match is rejected because "only members can register matches"

  Scenario: A super admin cannot be put on a match
    When "Alice" attempts to register a match in "Office Foosball" where "Alice" beats "Root" 21-8
    Then the match is rejected because "all players must be members of the account"

  Scenario: A super admin who is also a member behaves like any other member there
    # Carol stakes 10% of 1000 = 100 -> Root 1100, Carol 900
    Given "Root" is a member of the "Family" account
    When "Root" registers a match in "Family Foosball" where "Root" beats "Carol" 21-8
    Then the match is accepted
    And the "Family Foosball" scoreboard shows:
      | rank | player | points | played | won | lost | streak |
      | 1    | Root   | 1100   | 1      | 1   | 0    | W1     |
      | 2    | Carol  | 900    | 1      | 0   | 1    | L1     |
    And "Root" sees the member "Root" in the "Family" account
