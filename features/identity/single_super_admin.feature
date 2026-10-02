Feature: Single super admin
  Only one user in the whole system can be super admin. Granting super
  admin to a second, different user is rejected. Granting it again to the
  current super admin is a harmless no-op. Granting is a domain-level
  operation with no web UI.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Bob" is a registered user with email "bob@example.com" and password "secret123"

  # Single super admin 1
  Scenario: The first user granted becomes super admin
    When "Alice" is granted super admin
    Then the grant is accepted
    And "Alice" is a super admin

  # Single super admin 2
  Scenario: A second, different user cannot be made super admin
    Given "Alice" is a super admin
    When "Bob" is granted super admin
    Then the grant is rejected because "there can only be one super admin"
    And "Bob" is not a super admin
    And "Alice" is a super admin

  # Single super admin 3
  Scenario: Granting the current super admin again is idempotent
    Given "Alice" is a super admin
    When "Alice" is granted super admin
    Then the grant is accepted
    And "Alice" is a super admin
    And "Bob" is not a super admin

  # Single super admin 4
  Scenario: A rejected grant writes nothing
    Given "Alice" is a super admin
    When "Bob" is granted super admin
    Then no further super admin grant is recorded
