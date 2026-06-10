Feature: Register match
  A member registers a match result in an open league with fast entry: pick
  the players on each side and enter a score like 21-8. Sides have 1 or 2
  players (1v1 and 2v2). Draws are not allowed — the score decides the
  winner. All players must be distinct members of the account and scores
  must be non-negative integers.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Carol" is a registered user with email "carol@example.com" and password "secret123"
    And "Dave" is a registered user with email "dave@example.com" and password "secret123"
    And "Alice" owns the "Office" account
    And "Bob" is a member of the "Office" account
    And "Carol" is a member of the "Office" account
    And "Dave" is a member of the "Office" account
    And the "Office" account has an open league "Foosball Spring" for "Foosball" with starting points 1000 and stake 10%

  Scenario: Registering a 1v1 match
    When "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    Then the match is accepted
    And the recent matches in "Foosball Spring" show:
      | match                |
      | Alice beats Bob 21-8 |

  Scenario: Registering a 2v2 match
    When "Alice" registers a match in "Foosball Spring" where "Alice" and "Carol" beat "Bob" and "Dave" 10-4
    Then the match is accepted
    And the recent matches in "Foosball Spring" show:
      | match                                   |
      | Alice and Carol beat Bob and Dave 10-4  |

  Scenario Outline: Draws and invalid scores are rejected
    When "Alice" attempts to register a match in "Foosball Spring" where "Alice" plays "Bob" with home score "<home>" and away score "<away>"
    Then the match is rejected because "<reason>"

    Examples:
      | home | away | reason                               |
      | 10   | 10   | draws are not allowed                |
      | 0    | 0    | draws are not allowed                |
      | -1   | 21   | scores must be non-negative integers |
      | 21   | -3   | scores must be non-negative integers |
      | 21.5 | 8    | scores must be non-negative integers |

  Scenario: A player cannot be on both sides of a 2v2 match
    When "Alice" attempts to register a match in "Foosball Spring" where "Alice" and "Bob" beat "Bob" and "Carol" 10-4
    Then the match is rejected because "a player cannot be on both sides"

  Scenario: A player cannot play against themselves
    When "Alice" attempts to register a match in "Foosball Spring" where "Alice" beats "Alice" 21-8
    Then the match is rejected because "a player cannot be on both sides"

  Scenario: All players must be members of the account
    Given "Eve" is a registered user with email "eve@example.com" and password "secret123"
    When "Alice" attempts to register a match in "Foosball Spring" where "Alice" beats "Eve" 21-8
    Then the match is rejected because "all players must be members of the account"

  Scenario: Only members can register matches
    Given "Eve" is a registered user with email "eve@example.com" and password "secret123"
    When "Eve" attempts to register a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    Then the match is rejected because "only members can register matches"

  Scenario: Matches cannot be registered in a closed league
    Given "Alice" closes the "Foosball Spring" league
    When "Alice" attempts to register a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    Then the match is rejected because "the league is closed"
