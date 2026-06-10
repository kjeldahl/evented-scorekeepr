Feature: Invite players
  Members invite players into an account by email. The invited user — once
  registered and signed in with that email — sees the pending invitation and
  accepts it, becoming a member. An invitation can be accepted only once and
  only by a user whose email matches the invitation. Only members can see an
  account or invite players to it.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Alice" owns the "Office" account

  Scenario: A member invites a player by email
    When "Alice" invites "bob@example.com" to the "Office" account
    Then "bob@example.com" has a pending invitation to the "Office" account

  Scenario: The invited user sees the pending invitation after registering and signing in
    Given "Alice" invites "bob@example.com" to the "Office" account
    When someone signs up with name "Bob", email "bob@example.com" and password "secret123"
    And "Bob" signs in with email "bob@example.com" and password "secret123"
    Then "Bob" sees a pending invitation to the "Office" account

  Scenario: Accepting an invitation makes the invited user a member
    Given "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Alice" invites "bob@example.com" to the "Office" account
    When "Bob" accepts the invitation to the "Office" account
    Then "Bob" is a member of the "Office" account
    And "Bob" can see the "Office" account

  Scenario: An invitation can only be accepted once
    Given "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Alice" invites "bob@example.com" to the "Office" account
    And "Bob" accepts the invitation to the "Office" account
    When "Bob" attempts to accept the invitation to the "Office" account
    Then the invitation acceptance is rejected because "the invitation has already been accepted"

  Scenario: Only a user whose email matches the invitation can accept it
    Given "Carol" is a registered user with email "carol@example.com" and password "secret123"
    And "Alice" invites "bob@example.com" to the "Office" account
    When "Carol" attempts to accept the invitation to the "Office" account
    Then the invitation acceptance is rejected because "the invitation was not sent to this user's email"
    And "Carol" is not a member of the "Office" account

  Scenario: A non-member cannot see the account
    Given "Carol" is a registered user with email "carol@example.com" and password "secret123"
    Then "Carol" cannot see the "Office" account

  Scenario: A non-member cannot invite players to the account
    Given "Carol" is a registered user with email "carol@example.com" and password "secret123"
    When "Carol" attempts to invite "dave@example.com" to the "Office" account
    Then the invitation is rejected because "only members can invite players"
    And "dave@example.com" has no pending invitation to the "Office" account
