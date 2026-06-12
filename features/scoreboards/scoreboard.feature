Feature: Scoreboard
  The league page shows the standings plus the most recent matches.
  The recent-matches list is capped at 5 entries (newest first); there is no
  period filter, the cap is unconditional. Standings are ranked by points;
  for each player it shows points, matches played, wins, losses, win
  percentage, game points scored (for) and conceded (against), and the
  current streak (e.g. W2 / L1). Players appear on the scoreboard after
  their first registered match. Players tied on points are ordered by name;
  ranks continue sequentially (simplest reading of "ties share order by
  name").

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

  Scenario: The scoreboard is empty before any match is registered
    Then the "Foosball Spring" scoreboard shows no players

  Scenario: Players appear on the scoreboard after their first match
    # Bob stakes 10% of 1000 = 100: Alice 1100, Bob 900
    When "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    Then the "Foosball Spring" scoreboard shows:
      | rank | player | points | played | won | lost | streak |
      | 1    | Alice  | 1100   | 1      | 1   | 0    | W1     |
      | 2    | Bob    | 900    | 1      | 0   | 1    | L1     |
    And "Carol" does not appear on the "Foosball Spring" scoreboard

  Scenario: Standings after a series of matches
    # Match 1: Alice beats Bob 21-8   -> Bob stakes 100: Alice 1100, Bob 900
    # Match 2: Bob beats Carol 21-15  -> Carol enters at 1000, stakes 100: Carol 900, Bob 1000
    # Match 3: Alice beats Carol 21-18 -> Carol stakes 10% of 900 = 90: Carol 810, Alice 1190
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" registers a match in "Foosball Spring" where "Bob" beats "Carol" 21-15
    When "Alice" registers a match in "Foosball Spring" where "Alice" beats "Carol" 21-18
    Then the "Foosball Spring" scoreboard shows:
      | rank | player | points | played | won | lost | streak |
      | 1    | Alice  | 1190   | 2      | 2   | 0    | W2     |
      | 2    | Bob    | 1000   | 2      | 1   | 1    | W1     |
      | 3    | Carol  | 810    | 2      | 0   | 2    | L2     |

  Scenario: Full statistics including win percentage and game points
    # Same three matches as above.
    # Alice: scored 21+21 = 42, conceded 8+18 = 26, 2/2 wins = 100%
    # Bob:   scored 8+21  = 29, conceded 21+15 = 36, 1/2 wins = 50%
    # Carol: scored 15+18 = 33, conceded 21+21 = 42, 0/2 wins = 0%
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" registers a match in "Foosball Spring" where "Bob" beats "Carol" 21-15
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Carol" 21-18
    Then the "Foosball Spring" scoreboard statistics show:
      | rank | player | points | played | won | lost | win % | points for | points against | streak |
      | 1    | Alice  | 1190   | 2      | 2   | 0    | 100   | 42         | 26             | W2     |
      | 2    | Bob    | 1000   | 2      | 1   | 1    | 50    | 29         | 36             | W1     |
      | 3    | Carol  | 810    | 2      | 0   | 2    | 0     | 33         | 42             | L2     |

  Scenario: Recent matches are listed newest first
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" registers a match in "Foosball Spring" where "Bob" beats "Carol" 21-15
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Carol" 21-18
    Then the recent matches in "Foosball Spring" show:
      | match                   |
      | Alice beats Carol 21-18 |
      | Bob beats Carol 21-15   |
      | Alice beats Bob 21-8    |

  Scenario: Recent matches list is capped at 5 when more than 5 matches exist
    # Register 6 matches in order; only the 5 most recent must appear.
    # Match 1 (oldest): Alice beats Bob 21-8   -- must NOT appear
    # Match 2: Bob beats Carol 21-15
    # Match 3: Alice beats Carol 21-18
    # Match 4: Dave beats Alice 21-10
    # Match 5: Carol beats Bob 21-14
    # Match 6 (newest): Alice beats Dave 21-9
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" registers a match in "Foosball Spring" where "Bob" beats "Carol" 21-15
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Carol" 21-18
    And "Alice" registers a match in "Foosball Spring" where "Dave" beats "Alice" 21-10
    And "Alice" registers a match in "Foosball Spring" where "Carol" beats "Bob" 21-14
    When "Alice" registers a match in "Foosball Spring" where "Alice" beats "Dave" 21-9
    Then the recent matches in "Foosball Spring" show:
      | match                   |
      | Alice beats Dave 21-9   |
      | Carol beats Bob 21-14   |
      | Dave beats Alice 21-10  |
      | Alice beats Carol 21-18 |
      | Bob beats Carol 21-15   |

  Scenario: Statistics update as each match is registered
    # Match 1: Bob stakes 100 -> Alice 1100, Bob 900
    When "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    Then the "Foosball Spring" scoreboard shows:
      | rank | player | points | played | won | lost | streak |
      | 1    | Alice  | 1100   | 1      | 1   | 0    | W1     |
      | 2    | Bob    | 900    | 1      | 0   | 1    | L1     |
    # Match 2: Alice stakes 10% of 1100 = 110 -> Alice 990, Bob 1010
    When "Alice" registers a match in "Foosball Spring" where "Bob" beats "Alice" 21-19
    Then the "Foosball Spring" scoreboard shows:
      | rank | player | points | played | won | lost | streak |
      | 1    | Bob    | 1010   | 2      | 1   | 1    | W1     |
      | 2    | Alice  | 990    | 2      | 1   | 1    | L1     |

  Scenario: Players tied on points are ordered by name
    # Both winners gain 100 (1100), both losers lose 100 (900)
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    When "Alice" registers a match in "Foosball Spring" where "Carol" beats "Dave" 21-8
    Then the "Foosball Spring" scoreboard shows:
      | rank | player | points | played | won | lost | streak |
      | 1    | Alice  | 1100   | 1      | 1   | 0    | W1     |
      | 2    | Carol  | 1100   | 1      | 1   | 0    | W1     |
      | 3    | Bob    | 900    | 1      | 0   | 1    | L1     |
      | 4    | Dave   | 900    | 1      | 0   | 1    | L1     |
