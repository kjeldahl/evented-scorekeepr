Feature: Sign in and sign out
  A registered user signs in with email and password. Failed sign-ins do not
  reveal whether the email exists: wrong password and unknown email fail the
  same way.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"

  Scenario: Signing in with correct credentials
    When "Alice" signs in with email "alice@example.com" and password "secret123"
    Then the sign-in is accepted
    And "Alice" is signed in

  Scenario: Signing in with the wrong password is rejected
    When "Alice" signs in with email "alice@example.com" and password "wrong-secret"
    Then the sign-in is rejected because "invalid credentials"
    And "Alice" is not signed in

  Scenario: Signing in with an unknown email is rejected
    When someone signs in with email "nobody@example.com" and password "secret123"
    Then the sign-in is rejected because "invalid credentials"

  Scenario: Signing out
    Given "Alice" is signed in
    When "Alice" signs out
    Then "Alice" is not signed in
