Feature: Close league
  A league runs until a member explicitly closes it; the end need not be
  known up front. Once closed, no new matches can be registered in it, but
  its scoreboard remains visible to members.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Alice" owns the "Office" account
    And "Bob" is a member of the "Office" account
    And the "Office" account has an open league "Foosball Spring" for "Foosball" with starting points 1000 and stake 10%

  Scenario: A member closes a league
    When "Alice" closes the "Foosball Spring" league
    Then the "Foosball Spring" league is closed

  Scenario: No matches can be registered in a closed league
    Given "Alice" closes the "Foosball Spring" league
    When "Alice" attempts to register a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    Then the match is rejected because "the league is closed"

  Scenario: The scoreboard remains visible after the league is closed
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    When "Alice" closes the "Foosball Spring" league
    Then the "Foosball Spring" scoreboard shows:
      | rank | player | points | played | won | lost | streak |
      | 1    | Alice  | 1100   | 1      | 1   | 0    | W1     |
      | 2    | Bob    | 900    | 1      | 0   | 1    | L1     |
    And the recent matches in "Foosball Spring" show:
      | match                |
      | Alice beats Bob 21-8 |
