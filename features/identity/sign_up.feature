Feature: Sign up
  A person registers once with a name, an email and a password and becomes a
  user. Emails are normalised (lowercased, stripped) before use, so an email
  can register only once regardless of letter case.

  Scenario: Registering with name, email and password
    When someone signs up with name "Alice", email "alice@example.com" and password "secret123"
    Then the sign-up is accepted
    And "Alice" is a registered user with email "alice@example.com"

  Scenario: A duplicate email is rejected
    Given "Bob" is a registered user with email "bob@x.com" and password "secret123"
    When someone signs up with name "Robert", email "bob@x.com" and password "other-secret"
    Then the sign-up is rejected because "email is already registered"

  Scenario: A duplicate email is rejected regardless of letter case
    Given "Bob" is a registered user with email "bob@x.com" and password "secret123"
    When someone signs up with name "Robert", email "BOB@x.com" and password "other-secret"
    Then the sign-up is rejected because "email is already registered"

  Scenario Outline: Blank fields are rejected
    When someone signs up with name "<name>", email "<email>" and password "<password>"
    Then the sign-up is rejected because "<reason>"

    Examples:
      | name  | email             | password  | reason               |
      |       | alice@example.com | secret123 | name is required     |
      | Alice |                   | secret123 | email is required    |
      | Alice | alice@example.com |           | password is required |
