Feature: TV mode / live dashboard
  The TV dashboard is a read-only, full-screen page intended for a display
  in the room where games are played. It shows the league name, game type,
  the current standings (player, points, streak — same stake-model numbers
  as the scoreboard), and the five most recent matches, newest first.

  Two spotlights appear when the data warrants them:
  - Leader spotlight: the rank-1 player shown as the current leader with
    their points.
  - Hot-streak spotlight: the player with the longest current winning streak
    of at least 2 wins in a row. When two players share the same streak
    length, the player ranked higher in the standings is highlighted. When
    nobody has a winning streak of 2 or more, the spotlight is absent.

  The page self-refreshes via websocket push: when a league event is appended
  (a match result is registered or deleted, the league is renamed or closed),
  a live update is pushed over ActionCable to every TV screen watching that
  league,
  and the page refreshes itself immediately. A screen that reconnects after a
  network drop compares the league's current version against the version it
  last saw and refreshes if it missed anything. The version is a monotonic
  count of the league's events and increases with every new result.

  Only account members may view the TV dashboard; a super admin (read-only
  privilege) may also view it without being a member. An unauthenticated
  visitor is sent to sign in. A non-member who is signed in but is not a
  super admin is refused with "only members can view this league" — the same
  copy used by the scoreboard.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Carol" is a registered user with email "carol@example.com" and password "secret123"
    And "Dave" is a registered user with email "dave@example.com" and password "secret123"
    And "Frank" is a registered user with email "frank@example.com" and password "secret123"
    And "Alice" owns the "Office" account
    And "Bob" is a member of the "Office" account
    And "Carol" is a member of the "Office" account
    And "Dave" is a member of the "Office" account
    And the "Office" account has an open league "Foosball Spring" for "Foosball" with starting points 1000 and stake 10%

  # ---------------------------------------------------------------------------
  # Reaching the TV dashboard
  # ---------------------------------------------------------------------------

  Scenario: The scoreboard page links to the TV dashboard
    When "Alice" follows the TV mode link on the "Foosball Spring" scoreboard
    Then the TV dashboard shows the league name "Foosball Spring" and game type "Foosball"

  # ---------------------------------------------------------------------------
  # Empty state
  # ---------------------------------------------------------------------------

  Scenario: TV dashboard shows an empty state before any match is played
    When "Alice" opens the TV dashboard for the "Foosball Spring" league
    Then the TV dashboard shows the league name "Foosball Spring" and game type "Foosball"
    And the TV dashboard shows no players in the standings
    And the TV dashboard shows no recent matches
    And the TV dashboard shows no leader spotlight
    And the TV dashboard shows no hot-streak spotlight

  # ---------------------------------------------------------------------------
  # Standings and spotlights after matches
  # ---------------------------------------------------------------------------

  Scenario: Standings, leader spotlight and hot-streak spotlight after a series of matches
    # Match 1: Alice beats Bob 21-8
    #   -> Bob stakes 10% of 1000 = 100: Alice 1100, Bob 900
    # Match 2: Bob beats Carol 21-15
    #   -> Carol enters at 1000, stakes 100: Bob 1000, Carol 900
    # Match 3: Alice beats Carol 21-18
    #   -> Carol stakes 10% of 900 = 90: Alice 1190, Carol 810
    # Standings: 1 Alice 1190 W2, 2 Bob 1000 W1, 3 Carol 810 L2
    # Leader spotlight: Alice with 1190 points
    # Hot-streak spotlight: Alice with W2 (only streak of 2+)
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" registers a match in "Foosball Spring" where "Bob" beats "Carol" 21-15
    When "Alice" registers a match in "Foosball Spring" where "Alice" beats "Carol" 21-18
    And "Alice" opens the TV dashboard for the "Foosball Spring" league
    Then the TV dashboard standings show:
      | rank | player | points | streak |
      | 1    | Alice  | 1190   | W2     |
      | 2    | Bob    | 1000   | W1     |
      | 3    | Carol  | 810    | L2     |
    And the TV dashboard shows the leader spotlight for "Alice" with 1190 points
    And the TV dashboard shows the hot-streak spotlight "Alice is on fire — 2 wins in a row"

  Scenario: Hot-streak spotlight reflects the longest winning streak
    # Match 1: Alice beats Bob 21-8
    #   -> Bob stakes 100: Alice 1100, Bob 900
    # Match 2: Alice beats Carol 21-8
    #   -> Carol enters at 1000, stakes 100: Alice 1200, Carol 900
    # Match 3: Alice beats Bob 21-14
    #   -> Bob stakes 10% of 900 = 90: Alice 1290, Bob 810
    # Standings: 1 Alice 1290 W3, 2 Carol 900 L1, 3 Bob 810 L2
    # Hot-streak spotlight: Alice with W3
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Carol" 21-8
    When "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-14
    And "Alice" opens the TV dashboard for the "Foosball Spring" league
    Then the TV dashboard shows the hot-streak spotlight "Alice is on fire — 3 wins in a row"

  Scenario: Hot-streak spotlight is absent when no player has a winning streak of 2 or more
    # Alice and Bob each have exactly 1 win; no streak of 2+
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    When "Alice" registers a match in "Foosball Spring" where "Bob" beats "Carol" 21-15
    And "Alice" opens the TV dashboard for the "Foosball Spring" league
    Then the TV dashboard shows no hot-streak spotlight

  Scenario: Ties in streak length are broken by standings rank
    # Match 1: Alice beats Bob 21-8
    #   -> Bob stakes 100: Alice 1100, Bob 900
    # Match 2: Alice beats Carol 21-8
    #   -> Carol enters at 1000, stakes 100: Alice 1200, Carol 900
    # Match 3: Bob beats Dave 21-8
    #   -> Dave enters at 1000, stakes 100: Bob 1000, Dave 900
    # Match 4: Bob beats Dave 21-10
    #   -> Dave stakes 10% of 900 = 90: Bob 1090, Dave 810
    # Standings: 1 Alice 1200 W2, 2 Bob 1090 W2, 3 Carol 900 L1, 4 Dave 810 L2
    # Alice and Bob both have W2; Alice ranks higher so she takes the spotlight
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Carol" 21-8
    And "Alice" registers a match in "Foosball Spring" where "Bob" beats "Dave" 21-8
    When "Alice" registers a match in "Foosball Spring" where "Bob" beats "Dave" 21-10
    And "Alice" opens the TV dashboard for the "Foosball Spring" league
    Then the TV dashboard shows the hot-streak spotlight "Alice is on fire — 2 wins in a row"

  # ---------------------------------------------------------------------------
  # Recent matches — limited to the 5 most recent, newest first
  # ---------------------------------------------------------------------------

  Scenario: Recent matches are listed newest first, limited to 5
    # Six matches registered; the TV dashboard shows only the five most recent.
    # Match 1: Alice beats Bob 21-8     (oldest — dropped from the display)
    # Match 2: Bob beats Carol 21-15
    # Match 3: Alice beats Carol 21-18
    # Match 4: Alice beats Bob 21-11
    # Match 5: Alice beats Carol 21-14
    # Match 6: Bob beats Dave 21-10
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" registers a match in "Foosball Spring" where "Bob" beats "Carol" 21-15
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Carol" 21-18
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-11
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Carol" 21-14
    When "Alice" registers a match in "Foosball Spring" where "Bob" beats "Dave" 21-10
    And "Alice" opens the TV dashboard for the "Foosball Spring" league
    Then the TV dashboard recent matches show:
      | match                   |
      | Bob beats Dave 21-10    |
      | Alice beats Carol 21-14 |
      | Alice beats Bob 21-11   |
      | Alice beats Carol 21-18 |
      | Bob beats Carol 21-15   |

  # ---------------------------------------------------------------------------
  # Live-update version contract
  # ---------------------------------------------------------------------------

  Scenario: Registering a new match result advances the TV version
    # Reconnect catch-up contract: a screen that rejoins after a network drop
    # compares the version it last saw against the current version. The
    # observable guarantee: the version after a new match is strictly greater
    # than the version before it, so the screen knows it missed something.
    Given "Alice" is watching the TV dashboard for the "Foosball Spring" league
    When "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    Then the TV dashboard for "Foosball Spring" reports a newer version

  Scenario: Registering a new match result pushes a live update to TV dashboards
    Given "Alice" is watching the TV dashboard for the "Foosball Spring" league
    When "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    Then a live update is pushed to the "Foosball Spring" TV dashboard

  Scenario: Deleting a match result advances the TV version
    # A deletion re-derives the standings, so a screen that missed it must
    # refresh: deleting a match advances the version just like registering one.
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" is watching the TV dashboard for the "Foosball Spring" league
    When "Bob" deletes the match where "Alice" beats "Bob" 21-8 in "Foosball Spring"
    Then the TV dashboard for "Foosball Spring" reports a newer version

  Scenario: Deleting a match result pushes a live update to TV dashboards
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    And "Alice" is watching the TV dashboard for the "Foosball Spring" league
    When "Bob" deletes the match where "Alice" beats "Bob" 21-8 in "Foosball Spring"
    Then a live update is pushed to the "Foosball Spring" TV dashboard

  # ---------------------------------------------------------------------------
  # Access control
  # ---------------------------------------------------------------------------

  Scenario: Any account member can view the TV dashboard
    # Bob is a non-owner member; Carol is also a member
    Given "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    Then "Bob" can see the TV dashboard for the "Foosball Spring" league
    And "Carol" can see the TV dashboard for the "Foosball Spring" league

  Scenario: A non-member is refused access to the TV dashboard
    When "Frank" attempts to view the TV dashboard for the "Foosball Spring" league
    Then access is refused with "only members can view this league"

  Scenario: A guest (unauthenticated visitor) is redirected to sign in
    When a guest attempts to view the TV dashboard for the "Foosball Spring" league
    Then the guest is sent to sign in

  Scenario: A super admin may view the TV dashboard without being a member
    Given "Root" is a registered user with email "root@example.com" and password "secret123"
    And "Root" is a super admin
    And "Alice" registers a match in "Foosball Spring" where "Alice" beats "Bob" 21-8
    When "Root" opens the TV dashboard for the "Foosball Spring" league
    Then the TV dashboard standings show:
      | rank | player | points | streak |
      | 1    | Alice  | 1100   | W1     |
      | 2    | Bob    | 900    | L1     |
