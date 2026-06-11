Feature: Outgoing invitations
  The account page lists the account's outgoing invitations — the invites
  that were sent but not yet accepted — so members can see who is still
  missing. Outside production a member can also accept an outgoing
  invitation on behalf of the invited player (a development convenience for
  populating accounts), provided that player has already registered; every
  acceptance invariant still holds.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Alice" owns the "Office" account

  Scenario: A member sees the account's outgoing invitations
    Given "Alice" invites "bob@example.com" to the "Office" account
    Then "Alice" sees an outgoing invitation to "bob@example.com" in the "Office" account

  Scenario: An accepted invitation is no longer outgoing
    Given "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Alice" invites "bob@example.com" to the "Office" account
    When "Bob" accepts the invitation to the "Office" account
    Then "Alice" sees no outgoing invitation to "bob@example.com" in the "Office" account

  Scenario: A member accepts an outgoing invitation on behalf of a registered player
    Given "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Alice" invites "bob@example.com" to the "Office" account
    When "Alice" accepts the outgoing invitation to "bob@example.com" in the "Office" account on behalf of the invited player
    Then "Bob" is a member of the "Office" account
    And "Alice" sees no outgoing invitation to "bob@example.com" in the "Office" account

  Scenario: Accepting on behalf requires the invited player to be registered
    Given "Alice" invites "dave@example.com" to the "Office" account
    When "Alice" accepts the outgoing invitation to "dave@example.com" in the "Office" account on behalf of the invited player
    Then the invitation acceptance is rejected because "the invited player has not registered yet"
    And "dave@example.com" has a pending invitation to the "Office" account
