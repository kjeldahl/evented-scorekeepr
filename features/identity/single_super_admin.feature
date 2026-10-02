Feature: Single super admin
  At most one user in the system can be the super admin. Granting super
  admin status to a second, different user is rejected. Granting it again
  to the current super admin is a harmless no-op. How the grant is invoked
  is out of scope here (no web UI); "is a super admin" stays the contract
  used by the super admin features.

  Background:
    Given "Root" is a registered user with email "root@example.com" and password "secret123"
    And "Alice" is a registered user with email "alice@example.com" and password "secret123"

  # Single super admin 1
  Scenario: The first user granted becomes the super admin
    When "Root" is made a super admin
    Then "Root" is the super admin

  # Single super admin 2
  Scenario: A second user cannot be made a super admin
    Given "Root" is a super admin
    When an attempt is made to make "Alice" a super admin
    Then the grant is rejected because "there is already a super admin"
    And "Alice" is not the super admin
    And "Root" is the super admin

  # Single super admin 3
  Scenario: Granting the current super admin again succeeds
    Given "Root" is a super admin
    When "Root" is made a super admin
    Then "Root" is the super admin
    And "Alice" is not the super admin
