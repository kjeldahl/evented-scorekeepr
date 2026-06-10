Feature: Stake scoring
  Zero-sum stake model: each player enters the standings with the league's
  starting points the first time they appear in a match. When a match is
  registered, each losing player stakes stake% of their current points,
  rounded down (integer division). The pot — the sum of all stakes — is
  split among the winners with integer division; the remainder is handed
  out one point at a time to winners in the order they were listed on the
  match. Because the stake is always a percentage of current points, a
  player's points can never go negative.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Carol" is a registered user with email "carol@example.com" and password "secret123"
    And "Dave" is a registered user with email "dave@example.com" and password "secret123"
    And "Eve" is a registered user with email "eve@example.com" and password "secret123"
    And "Alice" owns the "Office" account
    And "Bob" is a member of the "Office" account
    And "Carol" is a member of the "Office" account
    And "Dave" is a member of the "Office" account
    And "Eve" is a member of the "Office" account

  Scenario: 1v1 win takes the loser's stake
    # Bob stakes 10% of 1000 = 100: Alice 1000 + 100 = 1100, Bob 1000 - 100 = 900
    Given the "Office" account has an open league "Foosball Spring" for "Foosball" with starting points 1000 and stake 10%
    When "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    Then "Alice" has 1100 points in "Foosball Spring"
    And "Bob" has 900 points in "Foosball Spring"

  Scenario: Stakes are taken from the loser's current points, not the starting points
    # Match 1: Bob stakes 100 -> Alice 1100, Bob 900
    # Match 2: Alice now loses and stakes 10% of 1100 = 110 -> Alice 990, Bob 1010
    Given the "Office" account has an open league "Foosball Spring" for "Foosball" with starting points 1000 and stake 10%
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    When "Alice" registers a match in "Foosball Spring" where "Bob" beats "Alice" 21-19
    Then "Alice" has 990 points in "Foosball Spring"
    And "Bob" has 1010 points in "Foosball Spring"

  Scenario: 2v2 pot is split evenly between the winners
    # Bob and Dave each stake 10% of 1000 = 100; pot = 200; each winner gains 100
    Given the "Office" account has an open league "Foosball Spring" for "Foosball" with starting points 1000 and stake 10%
    When "Alice" registers a match in "Foosball Spring" where "Alice" and "Carol" beat "Bob" and "Dave" 10-4
    Then "Alice" has 1100 points in "Foosball Spring"
    And "Carol" has 1100 points in "Foosball Spring"
    And "Bob" has 900 points in "Foosball Spring"
    And "Dave" has 900 points in "Foosball Spring"

  Scenario: An odd pot gives the extra point to the first-listed winner
    # Match 1: Alice beats Bob -> Alice 1100, Bob 900
    # Match 2: Bob beats Alice, Alice stakes 110 -> Alice 990, Bob 1010
    # Match 3: Bob stakes 10% of 1010 = 101, Carol stakes 10% of 1000 = 100; pot = 201
    #          each winner gains 201 / 2 = 100; remainder 1 goes to Dave (listed first)
    #          Dave 1000 + 101 = 1101, Eve 1000 + 100 = 1100, Bob 1010 - 101 = 909, Carol 1000 - 100 = 900
    Given the "Office" account has an open league "Foosball Spring" for "Foosball" with starting points 1000 and stake 10%
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" registers a match in "Foosball Spring" where "Bob" beats "Alice" 21-19
    When "Alice" registers a match in "Foosball Spring" where "Dave" and "Eve" beat "Bob" and "Carol" 10-7
    Then "Dave" has 1101 points in "Foosball Spring"
    And "Eve" has 1100 points in "Foosball Spring"
    And "Bob" has 909 points in "Foosball Spring"
    And "Carol" has 900 points in "Foosball Spring"

  Scenario: The stake is rounded down
    # 10% of 1015 is 101.5; the stake rounds down to 101
    # Bob 1015 - 101 = 914, Alice 1015 + 101 = 1116
    Given the "Office" account has an open league "Rounding Cup" for "Foosball" with starting points 1015 and stake 10%
    When "Alice" registers a match in "Rounding Cup" where "Alice" beats "Bob" 21-8
    Then "Bob" has 914 points in "Rounding Cup"
    And "Alice" has 1116 points in "Rounding Cup"

  Scenario: A custom stake percentage changes how much the loser stakes
    # Bob stakes 20% of 1000 = 200: Alice 1200, Bob 800
    Given the "Office" account has an open league "High Rollers" for "Table Tennis" with starting points 1000 and stake 20%
    When "Alice" registers a match in "High Rollers" where "Alice" beats "Bob" 21-12
    Then "Alice" has 1200 points in "High Rollers"
    And "Bob" has 800 points in "High Rollers"

  Scenario: Repeated losses shrink the stake, so points never go negative
    # Loss 1: Bob stakes 10% of 1000 = 100 -> 900   (Alice 1100)
    # Loss 2: Bob stakes 10% of 900  = 90  -> 810   (Alice 1190)
    # Loss 3: Bob stakes 10% of 810  = 81  -> 729   (Alice 1271)
    Given the "Office" account has an open league "Foosball Spring" for "Foosball" with starting points 1000 and stake 10%
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-14
    When "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-17
    Then "Bob" has 729 points in "Foosball Spring"
    And "Alice" has 1271 points in "Foosball Spring"
