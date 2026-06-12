Feature: Player statistics
  Every player name on a scoreboard links to that player's statistics page
  in the league; "opens X's statistics page" follows that link. The page
  shows the player's current points, rank and matches played, their form
  (the last five results, most recent first, like "W W L" — fewer if fewer
  matches played), a head-to-head table with one row per opponent faced (an
  opponent is any player on the other side, in 1v1 and 2v2 alike; ordered
  by most played, then name), and the match history newest first with the
  player's points after each match (the running balance from the stake
  fold). The match history is paged ten matches per page — page one holds
  the newest — with Older/Newer links between pages. Like the scoreboard,
  a player page is visible to account members only.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Carol" is a registered user with email "carol@example.com" and password "secret123"
    And "Dave" is a registered user with email "dave@example.com" and password "secret123"
    And "Eve" is a registered user with email "eve@example.com" and password "secret123"
    And "Frank" is a registered user with email "frank@example.com" and password "secret123"
    And "Alice" owns the "Office" account
    And "Bob" is a member of the "Office" account
    And "Carol" is a member of the "Office" account
    And "Dave" is a member of the "Office" account
    And "Eve" is a member of the "Office" account
    And the "Office" account has an open league "Foosball Spring" for "Foosball" with starting points 1000 and stake 10%

  Scenario: A player's page shows current points, rank and matches played
    # Match 1: Alice beats Bob 21-8    -> Bob stakes 10% of 1000 = 100: Alice 1100, Bob 900
    # Match 2: Bob beats Carol 21-15   -> Carol enters at 1000, stakes 100: Bob 1000, Carol 900
    # Match 3: Alice beats Carol 21-18 -> Carol stakes 10% of 900 = 90: Alice 1190, Carol 810
    # Standings: 1 Alice 1190, 2 Bob 1000, 3 Carol 810; Alice and Bob played 2 each
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" registers a match in "Foosball Spring" where "Bob" beats "Carol" 21-15
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Carol" 21-18
    When "Alice" opens "Alice"'s statistics page in "Foosball Spring"
    Then the player page shows 1190 points, rank 1 and 2 matches played
    When "Alice" opens "Bob"'s statistics page in "Foosball Spring"
    Then the player page shows 1000 points, rank 2 and 2 matches played

  Scenario: Form lists the player's results most recent first
    # Alice's results in order: L (match 1), W (match 2), W (match 3)
    # Most recent first that is W W L; Bob's results read L W the same way
    Given "Alice" registers a match in "Foosball Spring" where "Bob" beats "Alice" 21-19
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Carol" 21-15
    When "Alice" opens "Alice"'s statistics page in "Foosball Spring"
    Then the player page shows form "W W L"
    When "Alice" opens "Bob"'s statistics page in "Foosball Spring"
    Then the player page shows form "L W"

  Scenario: Form shows only the last five results
    # Alice's six results in order: W W L W L W; the last five, most recent
    # first, are W L W L W — the oldest win (match 1) is dropped
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Carol" 21-12
    And "Alice" registers a match in "Foosball Spring" where "Bob" beats "Alice" 21-19
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-14
    And "Alice" registers a match in "Foosball Spring" where "Carol" beats "Alice" 21-18
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Dave" 21-10
    When "Alice" opens "Alice"'s statistics page in "Foosball Spring"
    Then the player page shows form "W L W L W"

  Scenario: Head-to-head counts everyone on the other side, ordered by most played then name
    # Alice's opponents:
    #   Bob   - matches 1 (won), 2 (lost), 3 (won)  -> played 3, won 2, lost 1
    #   Dave  - matches 3 (won), 4 (lost)           -> played 2, won 1, lost 1
    #   Carol - matches 5 (lost), 6 (won)           -> played 2, won 1, lost 1
    # Eve was only ever Alice's teammate (match 3), so she is not listed.
    # Bob leads on played; Carol and Dave are tied on 2 and ordered by name.
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" registers a match in "Foosball Spring" where "Bob" beats "Alice" 21-19
    And "Alice" registers a match in "Foosball Spring" where "Alice" and "Eve" beat "Bob" and "Dave" 10-4
    And "Alice" registers a match in "Foosball Spring" where "Dave" beats "Alice" 21-12
    And "Alice" registers a match in "Foosball Spring" where "Carol" beats "Alice" 21-15
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Carol" 21-17
    When "Alice" opens "Alice"'s statistics page in "Foosball Spring"
    Then the head-to-head table shows:
      | opponent | played | won | lost |
      | Bob      | 3      | 2   | 1    |
      | Carol    | 2      | 1   | 1    |
      | Dave     | 2      | 1   | 1    |

  Scenario: Match history is newest first with the player's points after each match
    # Match 1: Alice beats Bob 21-8  -> Bob stakes 10% of 1000 = 100: Alice 1100, Bob 900
    # Match 2: Bob beats Alice 21-19 -> Alice stakes 10% of 1100 = 110: Alice 990, Bob 1010
    # Match 3: Alice and Carol beat Bob and Dave 10-4
    #          -> Bob stakes 10% of 1010 = 101, Dave stakes 10% of 1000 = 100; pot = 201
    #          -> each winner gains 201 / 2 = 100; remainder 1 goes to Alice (listed first)
    #          -> Alice 990 + 101 = 1091, Carol 1000 + 100 = 1100
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" registers a match in "Foosball Spring" where "Bob" beats "Alice" 21-19
    And "Alice" registers a match in "Foosball Spring" where "Alice" and "Carol" beat "Bob" and "Dave" 10-4
    When "Alice" opens "Alice"'s statistics page in "Foosball Spring"
    Then the match history shows:
      | match                                  | points after |
      | Alice and Carol beat Bob and Dave 10-4 | 1091         |
      | Bob beats Alice 21-19                  | 990          |
      | Alice beats Bob 21-8                   | 1100         |

  Scenario: Match history is paged ten matches per page
    # Eleven Alice wins: page one shows the ten newest, and only the very
    # first match (which left Alice at 1000 + 100 = 1100) spills onto page
    # two, reached via the "Older" link.
    Given "Alice" registers 11 matches in "Foosball Spring" where "Alice" beats "Bob" 21-8
    When "Alice" opens "Alice"'s statistics page in "Foosball Spring"
    Then the match history shows 10 matches on page 1 of 2
    When "Alice" follows the "Older" match history link
    Then the match history shows 1 matches on page 2 of 2
    And the match history shows:
      | match                | points after |
      | Alice beats Bob 21-8 | 1100         |
    When "Alice" follows the "Newer" match history link
    Then the match history shows 10 matches on page 1 of 2

  Scenario: Only account members can see a player's statistics page
    # Match 1: Bob stakes 10% of 1000 = 100 -> Alice 1100, rank 1, 1 match
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    When "Bob" opens "Alice"'s statistics page in "Foosball Spring"
    Then the player page shows 1100 points, rank 1 and 1 matches played
    And "Frank" cannot see "Alice"'s statistics page in "Foosball Spring"
