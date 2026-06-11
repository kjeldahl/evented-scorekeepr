Feature: Rename league
  A member can rename an open league; the new name shows wherever the
  league appears (the account page and the scoreboard page). The name must
  be present and closed leagues keep their name.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Alice" owns the "Office" account
    And the "Office" account has an open league "Foosball Spring" for "Foosball" with starting points 1000 and stake 10%

  Scenario: A member renames a league
    When "Alice" renames the "Foosball Spring" league to "Foosball Summer"
    Then the league rename is accepted
    And the league is shown as "Foosball Summer" on its scoreboard page
    And the "Office" account lists the league "Foosball Summer"

  Scenario: A blank name is rejected
    When "Alice" attempts to rename the "Foosball Spring" league to ""
    Then the league rename is rejected because "name is required"
    And the league is shown as "Foosball Spring" on its scoreboard page

  Scenario: A closed league cannot be renamed
    Given "Alice" closes the "Foosball Spring" league
    When "Alice" attempts to rename the "Foosball Spring" league to "Foosball Summer"
    Then the league rename is rejected because "the league is closed"

  Scenario: A non-member cannot rename the league
    Given "Carol" is a registered user with email "carol@example.com" and password "secret123"
    When "Carol" attempts to rename the "Foosball Spring" league to "Carol's League"
    Then the league rename is rejected because "only members can rename leagues"
