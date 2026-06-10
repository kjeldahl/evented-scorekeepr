Feature: Create account
  An account is a tenant (an office, a family). A signed-in user creates an
  account and becomes its owner; the owner is a member from creation.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"

  Scenario: A signed-in user creates an account and becomes owner and member
    Given "Alice" is signed in
    When "Alice" creates an account named "Office"
    Then the account creation is accepted
    And "Alice" is the owner of the "Office" account
    And "Alice" is a member of the "Office" account

  Scenario: A guest cannot create an account
    When someone who is not signed in attempts to create an account named "Office"
    Then the account creation is rejected because "you must be signed in"

  Scenario: An account name is required
    Given "Alice" is signed in
    When "Alice" attempts to create an account named ""
    Then the account creation is rejected because "name is required"
