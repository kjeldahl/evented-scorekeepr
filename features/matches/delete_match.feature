Feature: Delete match result
  Any player who took part in a match can delete it in an open league, just
  as they can correct its score. Deleting is folded onto the match in league
  order like a correction, so the league re-derives as if the match had never
  been registered: it vanishes from the recent matches and every later
  standing is recomputed. Players who only appeared in the deleted match drop
  out of the standings. A deleted match is gone — it can no longer be deleted
  or edited. The "Delete match" action lives on the edit form, reachable only
  by a player of the match; deletion is authorised by participation, not by a
  separate membership check.

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

  # delete_match-1
  Scenario: Deleting a match removes it and re-derives the standings
    # Original league order:
    #   M1 Alice beats Bob 21-8  -> Bob stakes 100: Alice 1100, Bob 900
    #   M2 Alice beats Bob 21-10 -> Bob stakes 10% of 900 = 90: Alice 1190, Bob 810
    # After M1 is deleted the whole fold is re-derived from M2 alone:
    #   M2 Alice beats Bob 21-10 -> Bob stakes 100: Alice 1100, Bob 900
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-10
    When "Bob" deletes the match where "Alice" beats "Bob" 21-8 in "Foosball Spring"
    Then the recent matches in "Foosball Spring" show:
      | match                 |
      | Alice beats Bob 21-10 |
    And the "Foosball Spring" scoreboard statistics show:
      | rank | player | points | played | won | lost | win % | points for | points against | streak |
      | 1    | Alice  | 1100   | 1      | 1   | 0    | 100   | 21         | 10             | W1     |
      | 2    | Bob    | 900    | 1      | 0   | 1    | 0     | 10         | 21             | L1     |

  # delete_match-2
  Scenario: Deleting the only match empties the scoreboard
    # A player enters the standings the first time they appear in a match, so
    # deleting the only match they played drops them out entirely.
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    When "Bob" deletes the match where "Alice" beats "Bob" 21-8 in "Foosball Spring"
    Then the "Foosball Spring" scoreboard shows no players
    And the recent matches in "Foosball Spring" show:
      | match |

  # delete_match-3
  Scenario: Any of the four players can delete a 2v2 match
    # The delete is made by Dave, a losing player who did not register it.
    Given "Alice" registers a match in "Foosball Spring" where "Alice" and "Carol" beat "Bob" and "Dave" 10-4
    When "Dave" deletes the match where "Alice" and "Carol" beat "Bob" and "Dave" 10-4 in "Foosball Spring"
    Then the "Foosball Spring" scoreboard shows no players
    And the recent matches in "Foosball Spring" show:
      | match |

  # delete_match-4
  Scenario: A player sees a delete option on a match they played
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    Then "Bob" sees a delete button for the match where "Alice" beats "Bob" 21-8 in "Foosball Spring"

  # delete_match-5
  Scenario: A member who did not play in the match cannot delete it
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    When "Carol" attempts to delete the match where "Alice" beats "Bob" 21-8 in "Foosball Spring"
    Then the delete is rejected because "only players in the match can delete it"

  # delete_match-6
  Scenario: A non-member cannot delete a match
    Given "Eve" is a registered user with email "eve@example.com" and password "secret123"
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    When "Eve" attempts to delete the match where "Alice" beats "Bob" 21-8 in "Foosball Spring"
    Then the delete is rejected because "only players in the match can delete it"

  # delete_match-7
  Scenario: Matches cannot be deleted in a closed league
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" closes the "Foosball Spring" league
    When "Bob" attempts to delete the match where "Alice" beats "Bob" 21-8 in "Foosball Spring"
    Then the delete is rejected because "the league is closed"

  # delete_match-8
  Scenario: A deleted match cannot be deleted again
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Bob" deletes the match where "Alice" beats "Bob" 21-8 in "Foosball Spring"
    When "Bob" attempts to delete the match where "Alice" beats "Bob" 21-8 in "Foosball Spring"
    Then the delete is rejected because "the match was not found"

  # delete_match-9
  Scenario: A deleted match cannot be edited
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Bob" deletes the match where "Alice" beats "Bob" 21-8 in "Foosball Spring"
    When "Bob" attempts to edit the match where "Alice" beats "Bob" 21-8 in "Foosball Spring" with home score "21" and away score "18"
    Then the edit is rejected because "the match was not found"
