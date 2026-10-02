Feature: Super admin handoff
  The current super admin can hand super admin status over to another
  registered user (any registered user, identified by email). Afterwards the
  recipient is the one and only super admin and the previous super admin is
  an ordinary user again. Only the current super admin can hand off.

  Handoff is available in the UI: the super admin's dashboard links to a
  "Hand off super admin" page with the recipient's email and a password
  field. Because handing off is a sensitive action, the super admin must
  re-authenticate by entering their own current password every time; a
  wrong password rejects the handoff with "invalid credentials" and changes
  nothing. Ordinary users never see the link and are refused if they reach
  the page directly. When the handoff succeeds any impersonation session
  the previous super admin has in effect ends immediately (recorded in the
  audit trail like any other end of impersonation).

  Checks run in this order: the sender must be the super admin, then the
  password must be correct, then the recipient must exist. The first failure
  is the one reported.

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
  Scenario: Handing off to oneself keeps the super admin
    When "Root" hands super admin status off to "Root"
    Then "Root" is the super admin

  # Super admin handoff 6
  Scenario: Handing off to an unknown user is rejected
    When an attempt is made for "Root" to hand super admin status off to the email "nobody@example.com"
    Then the handoff is rejected because "the user was not found"
    And "Root" is the super admin

  # Super admin handoff 7
  Scenario: The previous super admin loses view access to accounts
    Given "Alice" owns the "Office" account
    When "Root" hands super admin status off to "Bob"
    Then "Root" cannot see the "Office" account
    And "Bob" can see the "Office" account

  # Super admin handoff 8
  Scenario: The sender is checked before the recipient
    When an attempt is made for "Alice" to hand super admin status off to the email "nobody@example.com"
    Then the handoff is rejected because "only the super admin can hand off super admin status"
    And "Root" is the super admin

  # Super admin handoff 9
  Scenario: The previous super admin can no longer impersonate players
    Given "Alice" owns the "Office" account
    And "Bob" is a member of the "Office" account
    And "Root" hands super admin status off to "Alice"
    When "Root" attempts to impersonate the member "Bob" in the "Office" account
    Then the impersonation is rejected because "only super admins can impersonate players"

  # Super admin handoff 10
  Scenario: A wrong password rejects the handoff
    When an attempt is made for "Root" to hand super admin status off to "Alice" with the password "wrong"
    Then the handoff is rejected because "invalid credentials"
    And "Root" is the super admin
    And "Alice" is not the super admin

  # Super admin handoff 11
  Scenario: Only the super admin sees the handoff link on their dashboard
    Then "Root" sees a link to hand off super admin status on their dashboard
    And "Alice" sees no link to hand off super admin status on their dashboard

  # Super admin handoff 12
  Scenario: An ordinary user is refused the handoff page
    Then "Alice" is refused access to the handoff page

  # Super admin handoff 13
  Scenario: The previous super admin is refused the handoff page
    Given "Root" hands super admin status off to "Alice"
    Then "Root" is refused access to the handoff page
    And "Alice" can open the handoff page

  # Super admin handoff 14
  Scenario: Handing off ends the previous super admin's impersonation immediately
    Given "Alice" owns the "Office" account
    And "Bob" is a member of the "Office" account
    And "Root" impersonates the member "Bob" in the "Office" account
    When "Root" hands super admin status off to "Alice"
    Then "Root" sees no impersonation notice
    And the audit trail records that "Root" stopped impersonating "Bob"
