Feature: Player handles
  A player can set a handle on their profile page. Wherever players are
  shown — account members, scoreboards and recent matches — the handle is
  displayed instead of the registered name; players without a handle are
  shown by their name. The latest handle wins and a handle must be present.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Alice" owns the "Office" account
    And "Bob" is a member of the "Office" account

  Scenario: The members list shows the handle instead of the name
    Given "Bob" sets the handle "Bobby"
    Then "Alice" sees the member "Bobby" in the "Office" account
    And "Alice" does not see the member "Bob" in the "Office" account

  Scenario: The scoreboard and recent matches show handles
    Given the "Office" account has an open league "Foosball Spring" for "Foosball" with starting points 1000 and stake 10%
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    When "Alice" sets the handle "Ace"
    Then the "Foosball Spring" scoreboard shows:
      | rank | player | points | played | won | lost | streak |
      | 1    | Ace    | 1100   | 1      | 1   | 0    | W1     |
      | 2    | Bob    | 900    | 1      | 0   | 1    | L1     |
    And the recent matches in "Foosball Spring" show:
      | match              |
      | Ace beats Bob 21-8 |

  Scenario: The latest handle wins
    Given "Bob" sets the handle "Bobby"
    When "Bob" sets the handle "Rocket"
    Then "Alice" sees the member "Rocket" in the "Office" account

  Scenario: A blank handle is rejected
    When "Bob" attempts to set the handle "   "
    Then the handle change is rejected because "handle is required"
