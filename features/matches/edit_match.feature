Feature: Edit match result
  Any player who took part in a match can correct its score in an open
  league. Only the score changes; the players and the sides are fixed.
  Any match in the league can be corrected, not just the latest: because
  scoring is derived by folding matches in league order, correcting an
  earlier match re-derives every later standing. Edited scores obey the
  same rules as a freshly registered match: non-negative integers and no
  draws.

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

  # edit_match-1
  Scenario: A player corrects the score without changing the winner
    # The stake is a percentage of the loser's points, not of the score
    # margin, so the standings points are unchanged; only the game points
    # for/against and the displayed match line change.
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    When "Bob" edits the match where "Alice" beats "Bob" 21-8 in "Foosball Spring" so that "Alice" beats "Bob" 21-18
    Then the recent matches in "Foosball Spring" show:
      | match                 |
      | Alice beats Bob 21-18 |
    And the "Foosball Spring" scoreboard statistics show:
      | rank | player | points | played | won | lost | win % | points for | points against | streak |
      | 1    | Alice  | 1100   | 1      | 1   | 0    | 100   | 21         | 18             | W1     |
      | 2    | Bob    | 900    | 1      | 0   | 1    | 0     | 18         | 21             | L1     |

  # edit_match-2
  Scenario: Flipping the winner re-derives the standings, including later matches
    # Original league order:
    #   M1 Alice beats Bob 21-8  -> Bob stakes 100: Alice 1100, Bob 900
    #   M2 Bob beats Alice 21-19 -> Alice stakes 10% of 1100 = 110: Alice 990, Bob 1010
    # After M1 is corrected so Bob wins 21-8, the whole fold is re-derived:
    #   M1 Bob beats Alice -> Alice stakes 100: Alice 900, Bob 1100
    #   M2 Bob beats Alice -> Alice stakes 10% of 900 = 90: Alice 810, Bob 1190
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" registers a match in "Foosball Spring" where "Bob" beats "Alice" 21-19
    When "Bob" edits the match where "Alice" beats "Bob" 21-8 in "Foosball Spring" so that "Bob" beats "Alice" 21-8
    Then "Alice" has 810 points in "Foosball Spring"
    And "Bob" has 1190 points in "Foosball Spring"
    And the recent matches in "Foosball Spring" show:
      | match                 |
      | Bob beats Alice 21-19 |
      | Bob beats Alice 21-8  |

  # edit_match-3
  Scenario: Any of the four players can edit a 2v2 match
    # The score change keeps the same winners, so the points are unchanged;
    # the edit is made by Dave, a losing player who did not register it.
    Given "Alice" registers a match in "Foosball Spring" where "Alice" and "Carol" beat "Bob" and "Dave" 10-4
    When "Dave" edits the match where "Alice" and "Carol" beat "Bob" and "Dave" 10-4 in "Foosball Spring" so that "Alice" and "Carol" beat "Bob" and "Dave" 21-19
    Then the recent matches in "Foosball Spring" show:
      | match                                   |
      | Alice and Carol beat Bob and Dave 21-19 |
    And "Alice" has 1100 points in "Foosball Spring"
    And "Bob" has 900 points in "Foosball Spring"

  # edit_match-4
  Scenario: A player sees an edit link on a match they played
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    Then "Bob" sees an edit link for the match where "Alice" beats "Bob" 21-8 in "Foosball Spring"

  # edit_match-5
  Scenario: A member who did not play sees no edit link on the match
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    Then "Carol" sees no edit link for the match where "Alice" beats "Bob" 21-8 in "Foosball Spring"

  # edit_match-6
  Scenario: A member who did not play in the match cannot edit it
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    When "Carol" attempts to edit the match where "Alice" beats "Bob" 21-8 in "Foosball Spring" with home score "21" and away score "18"
    Then the edit is rejected because "only players in the match can edit it"

  # edit_match-7
  Scenario: A non-member cannot edit a match
    Given "Eve" is a registered user with email "eve@example.com" and password "secret123"
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    When "Eve" attempts to edit the match where "Alice" beats "Bob" 21-8 in "Foosball Spring" with home score "21" and away score "18"
    Then the edit is rejected because "only players in the match can edit it"

  # edit_match-8
  Scenario: Matches cannot be edited in a closed league
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" closes the "Foosball Spring" league
    When "Bob" attempts to edit the match where "Alice" beats "Bob" 21-8 in "Foosball Spring" with home score "21" and away score "18"
    Then the edit is rejected because "the league is closed"

  # edit_match-9
  Scenario Outline: Draws and invalid scores are rejected on edit
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    When "Bob" attempts to edit the match where "Alice" beats "Bob" 21-8 in "Foosball Spring" with home score "<home>" and away score "<away>"
    Then the edit is rejected because "<reason>"

    Examples:
      | home | away | reason                               |
      | 10   | 10   | draws are not allowed                |
      | 0    | 0    | draws are not allowed                |
      | -1   | 21   | scores must be non-negative integers |
      | 21   | -3   | scores must be non-negative integers |
      | 21.5 | 8    | scores must be non-negative integers |
