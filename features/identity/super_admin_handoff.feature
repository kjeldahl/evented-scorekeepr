Feature: Super admin handoff
  The current super admin can hand the super admin status over to another
  registered user, identified by email. The handoff is a single atomic
  transfer: afterwards the recipient is the one and only super admin and the
  previous super admin is an ordinary user again. The control lives on the
  super admin's own profile page and is shown to nobody else. There is still
  never more than one super admin at any time. While impersonating, the
  super admin acts as the impersonated member and so cannot hand off.
  Design basis: a handoff appends a super admin revocation for the previous
  holder and a grant for the recipient atomically, so super admin status
  becomes latest-wins per user.

  Background:
    Given "Root" is a registered user with email "root@example.com" and password "secret123"
    And "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Root" is a super admin

  # Super admin handoff 1
  Scenario: The super admin hands the status over to another user
    When "Root" hands the super admin status to "alice@example.com"
    Then "Alice" is the super admin
    And "Root" is not the super admin

  # Super admin handoff 2
  Scenario: The previous super admin loses the privileges and the recipient gains them
    Given "Bob" owns the "Office" account
    When "Root" hands the super admin status to "alice@example.com"
    Then "Alice" can see the "Office" account
    And "Root" cannot see the "Office" account

  # Super admin handoff 3
  Scenario: The status can be handed on again
    Given "Root" has handed the super admin status to "alice@example.com"
    When "Alice" hands the super admin status to "bob@example.com"
    Then "Bob" is the super admin
    And "Alice" is not the super admin
    And "Root" is not the super admin

  # Super admin handoff 4
  Scenario: Only the super admin sees the handoff control
    Then "Root" sees the super admin handoff control on their profile page
    And "Alice" does not see the super admin handoff control on their profile page

  # Super admin handoff 9
  Scenario: The handoff control follows the status
    When "Root" hands the super admin status to "alice@example.com"
    Then "Alice" sees the super admin handoff control on their profile page
    And "Root" does not see the super admin handoff control on their profile page

  # Super admin handoff 10
  Scenario: A previous super admin cannot hand off again
    Given "Root" has handed the super admin status to "alice@example.com"
    When "Root" attempts to hand the super admin status to "bob@example.com"
    Then the handoff is rejected because "only the super admin can hand off the super admin status"
    And "Alice" is the super admin
    And "Bob" is not the super admin

  # Super admin handoff 11
  Scenario: A super admin impersonating a member cannot hand off
    Given "Alice" owns the "Office" account
    And "Root" impersonates the member "Alice" in the "Office" account
    When "Root" attempts to hand the super admin status to "bob@example.com"
    Then the handoff is rejected because "only the super admin can hand off the super admin status"
    And "Root" is the super admin
    And "Bob" is not the super admin

  # Super admin handoff 5
  Scenario: An ordinary user cannot hand off the status
    When "Alice" attempts to hand the super admin status to "bob@example.com"
    Then the handoff is rejected because "only the super admin can hand off the super admin status"
    And "Root" is the super admin
    And "Bob" is not the super admin

  # Super admin handoff 6
  Scenario Outline: The recipient must be a registered user
    When "Root" attempts to hand the super admin status to "<email>"
    Then the handoff is rejected because "there is no user with that email"
    And "Root" is the super admin

    Examples:
      | email               |
      | nobody@example.com  |
      |                     |

  # Super admin handoff 7
  Scenario: Handing the status to oneself is a no-op
    When "Root" hands the super admin status to "root@example.com"
    Then "Root" is the super admin
    And "Alice" is not the super admin

  # Super admin handoff 8
  Scenario: The recipient email is matched case-insensitively
    When "Root" hands the super admin status to "  ALICE@Example.com "
    Then "Alice" is the super admin
    And "Root" is not the super admin
