Feature: Create league
  A member creates a league in an account for one game type. Defaults are
  starting points 1000 and stake 10%. An account can host many open leagues
  at once, also for the same game type. League names must be present,
  starting points must be positive and the stake must be between 1 and 99.

  A league is either a match league (traditional 1v1 / 2v2 head-to-head) or
  a multiplayer league (all participants play independently; the winner is
  determined by ranking each participant's score and awarding points
  proportionally). The mode is chosen explicitly on the new-league form and
  is independent of the game type: any game type can be run in either mode.
  A league created without choosing a mode is a match league, as are
  existing leagues created before the mode existed.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Alice" owns the "Office" account

  # create_league-1
  Scenario: Creating a league with default starting points and stake
    When "Alice" creates a league "Foosball Spring" for "Foosball" in the "Office" account
    Then the league creation is accepted
    And the "Foosball Spring" league has starting points 1000 and stake 10%
    And the "Foosball Spring" league is open

  # create_league-2
  Scenario: Creating a league with custom starting points and stake
    When "Alice" creates a league "TT Masters" for "Table Tennis" in the "Office" account with starting points 1500 and stake 20%
    Then the league creation is accepted
    And the "TT Masters" league has starting points 1500 and stake 20%

  # create_league-3
  Scenario Outline: The mode chosen on the new-league form decides the league's mode
    When "Alice" creates a league "<name>" for "<game type>" in the "Office" account as a "<mode>" league
    Then the league creation is accepted
    And the "<name>" league is a "<mode>" league

    Examples: The same game type can run in either mode
      | name              | game type | mode        |
      | Foosball Spring   | Foosball  | match       |
      | Foosball Knockout | Foosball  | multiplayer |

    Examples: The mode is not implied by the game type
      | name              | game type | mode        |
      | Golf Championship | Golf      | multiplayer |
      | Golf Pairs        | Golf      | match       |

  # create_league-4
  Scenario: A league created without choosing a mode is a match league
    When "Alice" creates a league "Foosball Spring" for "Foosball" in the "Office" account
    Then the league creation is accepted
    And the "Foosball Spring" league is a "match" league

  # create_league-5
  Scenario: Several leagues can run in the same account at once, even for the same game type
    Given the "Office" account has an open league "Foosball Spring" for "Foosball" with starting points 1000 and stake 10%
    And the "Office" account has an open league "TT Masters" for "Table Tennis" with starting points 1000 and stake 10%
    When "Alice" creates a league "Foosball Lunch" for "Foosball" in the "Office" account
    Then the league creation is accepted
    And the "Foosball Spring" league is open
    And the "TT Masters" league is open
    And the "Foosball Lunch" league is open

  # create_league-6
  Scenario Outline: Invalid league settings are rejected
    When "Alice" attempts to create a league "<name>" for "Foosball" in the "Office" account with starting points <starting points> and stake <stake>%
    Then the league creation is rejected because "<reason>"

    Examples:
      | name            | starting points | stake | reason                           |
      |                 | 1000            | 10    | name is required                 |
      | Foosball Spring | 1000            | 0     | stake must be between 1 and 99   |
      | Foosball Spring | 1000            | 100   | stake must be between 1 and 99   |
      | Foosball Spring | 0               | 10    | starting points must be positive |
      | Foosball Spring | -100            | 10    | starting points must be positive |

  # create_league-7
  Scenario Outline: Stakes of 1 and 99 are within bounds
    When "Alice" creates a league "<name>" for "Foosball" in the "Office" account with starting points 1000 and stake <stake>%
    Then the league creation is accepted
    And the "<name>" league has starting points 1000 and stake <stake>%

    Examples:
      | name        | stake |
      | Low Stakes  | 1     |
      | High Stakes | 99    |

  # create_league-8
  Scenario: A non-member cannot create a league in the account
    Given "Carol" is a registered user with email "carol@example.com" and password "secret123"
    When "Carol" attempts to create a league "Carol's League" for "Foosball" in the "Office" account with starting points 1000 and stake 10%
    Then the league creation is rejected because "only members can create leagues"
