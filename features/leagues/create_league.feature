Feature: Create league
  A member creates a league in an account for one game type. Defaults are
  starting points 1000 and stake 10%. An account can host many open leagues
  at once, also for the same game type. League names must be present,
  starting points must be positive and the stake must be between 1 and 99.

  A league is either a match league (traditional 1v1 / 2v2 head-to-head) or
  a multiplayer league (all participants play independently; the winner is
  determined by ranking each participant's score and awarding points
  proportionally). A league's mode is selected explicitly when creating it;
  existing leagues created without a mode are match leagues.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Alice" owns the "Office" account

  Scenario: Creating a league with default starting points and stake
    When "Alice" creates a league "Foosball Spring" for "Foosball" in the "Office" account
    Then the league creation is accepted
    And the "Foosball Spring" league has starting points 1000 and stake 10%
    And the "Foosball Spring" league is open

  Scenario: Creating a league with custom starting points and stake
    When "Alice" creates a league "TT Masters" for "Table Tennis" in the "Office" account with starting points 1500 and stake 20%
    Then the league creation is accepted
    And the "TT Masters" league has starting points 1500 and stake 20%

  Scenario: A match league uses traditional 1v1 / 2v2 scoring
    When "Alice" creates a league "Foosball Spring" for "Foosball" in the "Office" account as a match league
    Then the "Foosball Spring" league is a match league

  Scenario: A multiplayer league uses rank-based scoring
    When "Alice" creates a league "Golf Championship" for "Golf" in the "Office" account as a multiplayer league
    Then the "Golf Championship" league is a multiplayer league

  Scenario: Several leagues can run in the same account at once, even for the same game type
    Given the "Office" account has an open league "Foosball Spring" for "Foosball" with starting points 1000 and stake 10%
    And the "Office" account has an open league "TT Masters" for "Table Tennis" with starting points 1000 and stake 10%
    When "Alice" creates a league "Foosball Lunch" for "Foosball" in the "Office" account
    Then the league creation is accepted
    And the "Foosball Spring" league is open
    And the "TT Masters" league is open
    And the "Foosball Lunch" league is open

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

  Scenario Outline: Stakes of 1 and 99 are within bounds
    When "Alice" creates a league "<name>" for "Foosball" in the "Office" account with starting points 1000 and stake <stake>%
    Then the league creation is accepted
    And the "<name>" league has starting points 1000 and stake <stake>%

    Examples:
      | name        | stake |
      | Low Stakes  | 1     |
      | High Stakes | 99    |

  Scenario: A non-member cannot create a league in the account
    Given "Carol" is a registered user with email "carol@example.com" and password "secret123"
    When "Carol" attempts to create a league "Carol's League" for "Foosball" in the "Office" account with starting points 1000 and stake 10%
    Then the league creation is rejected because "only members can create leagues"

  Scenario: A multiplayer league is marked as multiplayer in its configuration
    When "Alice" creates a league "Golf Championship" for "Golf" in the "Office" account as a multiplayer league
    And the league "Golf Championship" is a multiplayer league
    When "Alice" creates a league "Foosball Spring" for "Foosball" in the "Office" account as a multiplayer league
    And the league "Foosball Spring" is a multiplayer league