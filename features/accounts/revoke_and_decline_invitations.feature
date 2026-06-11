Feature: Revoke and decline invitations
  An outgoing invitation can be revoked by any member of the account, and
  declined by the invited user. A settled invitation — accepted, revoked or
  declined — disappears from the invitee's pending list and from the
  account's outgoing list, and cannot be acted on again.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Alice" owns the "Office" account
    And "Alice" invites "bob@example.com" to the "Office" account

  Scenario: A member revokes an outgoing invitation
    When "Alice" revokes the invitation to "bob@example.com" in the "Office" account
    Then "Alice" sees no outgoing invitation to "bob@example.com" in the "Office" account
    And "bob@example.com" has no pending invitation to the "Office" account

  Scenario: A revoked invitation cannot be accepted
    Given "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Alice" revokes the invitation to "bob@example.com" in the "Office" account
    When "Bob" attempts to accept the invitation to the "Office" account
    Then the invitation acceptance is rejected because "the invitation has been revoked"
    And "Bob" is not a member of the "Office" account

  Scenario: The invited user declines the invitation
    Given "Bob" is a registered user with email "bob@example.com" and password "secret123"
    When "Bob" declines the invitation to the "Office" account
    Then "Bob" is not a member of the "Office" account
    And "bob@example.com" has no pending invitation to the "Office" account
    And "Alice" sees no outgoing invitation to "bob@example.com" in the "Office" account

  Scenario: A declined invitation cannot be accepted
    Given "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Bob" declines the invitation to the "Office" account
    When "Bob" attempts to accept the invitation to the "Office" account
    Then the invitation acceptance is rejected because "the invitation has been declined"

  Scenario: Only a user whose email matches the invitation can decline it
    Given "Carol" is a registered user with email "carol@example.com" and password "secret123"
    When "Carol" attempts to decline the invitation to the "Office" account
    Then the invitation decline is rejected because "the invitation was not sent to this user's email"
    And "bob@example.com" has a pending invitation to the "Office" account

  Scenario: An accepted invitation can no longer be revoked
    Given "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Bob" accepts the invitation to the "Office" account
    When "Alice" attempts to revoke the invitation to "bob@example.com" in the "Office" account
    Then the invitation revocation is rejected because "the invitation is no longer pending"
    And "Bob" is a member of the "Office" account

  Scenario: A non-member cannot revoke an invitation
    Given "Carol" is a registered user with email "carol@example.com" and password "secret123"
    When "Carol" attempts to revoke the invitation to "bob@example.com" in the "Office" account
    Then the invitation revocation is rejected because "only members can revoke invitations"
    And "bob@example.com" has a pending invitation to the "Office" account
