Feature: Super admin handoff
  The current super admin can hand super admin status over to another
  registered user. Afterwards the recipient is the one and only super admin
  and the previous super admin is an ordinary user again. Only the current
  super admin can hand off. How the handoff is invoked is out of scope here
  (no web UI); "is a super admin" stays the contract used by the super admin
  features.

  Background:
    Given "Root" is a registered user with email "root@example.com" and password "secret123"
    And "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Root" is a super admin

  # Super admin handoff 1
  Scenario: The super admin hands off to another user
    When "Root" hands super admin status off to "Alice"
    Then "Alice" is the super admin
    And "Root" is not the super admin

  # Super admin handoff 2
  Scenario: The new super admin can hand off again
    Given "Root" hands super admin status off to "Alice"
    When "Alice" hands super admin status off to "Bob"
    Then "Bob" is the super admin
    And "Alice" is not the super admin
    And "Root" is not the super admin

  # Super admin handoff 3
  Scenario: The previous super admin can no longer hand off
    Given "Root" hands super admin status off to "Alice"
    When an attempt is made for "Root" to hand super admin status off to "Bob"
    Then the handoff is rejected because "only the super admin can hand off super admin status"
    And "Alice" is the super admin

  # Super admin handoff 4
  Scenario: An ordinary user cannot hand off
    When an attempt is made for "Alice" to hand super admin status off to "Bob"
    Then the handoff is rejected because "only the super admin can hand off super admin status"
    And "Root" is the super admin
    And "Bob" is not the super admin

  # Super admin handoff 5
  Scenario: Handing off to oneself is a no-op
    When "Root" hands super admin status off to "Root"
    Then "Root" is the super admin

  # Super admin handoff 6
  Scenario: Handing off to an unknown user is rejected
    When an attempt is made for "Root" to hand super admin status off to an unregistered user
    Then the handoff is rejected because "user not found"
    And "Root" is the super admin

  # Super admin handoff 7
  Scenario: The previous super admin loses view access to accounts
    Given "Alice" owns the "Office" account
    When "Root" hands super admin status off to "Bob"
    Then "Root" cannot see the "Office" account
    And "Bob" can see the "Office" account
