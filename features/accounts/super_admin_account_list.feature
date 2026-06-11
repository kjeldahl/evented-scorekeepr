Feature: Super admin all-accounts list
  A super admin can already view any account, scoreboard and player
  statistics page, but has had no way to discover them: the dashboard only
  shows a user's own memberships. This feature gives the super admin a
  read-only all-accounts list, reachable from their dashboard, that names
  every account in the system and lets them open each one, member or not.
  The list is a pure navigation entry point: it is sorted alphabetically by
  account name (DOMAIN.md is silent on ordering; this is the simplest
  reading), it offers no action other than opening an account, and it
  grants nothing new: opening an account from it is the same read-only view
  the super admin already has. Ordinary users never see the list and are
  refused if they try to reach it directly; their dashboards keep showing
  only their own memberships. A super admin's own dashboard likewise keeps
  showing only the accounts they are actually a member of; the all-accounts
  list is separate from membership.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Carol" is a registered user with email "carol@example.com" and password "secret123"
    And "Root" is a registered user with email "root@example.com" and password "secret123"
    And "Root" is a super admin
    And "Alice" owns the "Office" account
    And "Carol" owns the "Family" account
    And "Bob" is a member of the "Office" account

  Scenario: A super admin reaches the all-accounts list from their dashboard
    Then "Root" sees a link to the all-accounts list on their dashboard

  Scenario: The all-accounts list shows every account in the system
    Given "Bob" owns the "Bowling Buddies" account
    Then "Root" sees the all-accounts list:
      | account         |
      | Bowling Buddies |
      | Family          |
      | Office          |

  Scenario: A super admin opens an account they are not a member of from the list
    Given "Root" is not a member of the "Family" account
    When "Root" opens the "Family" account from the all-accounts list
    Then "Root" can see the "Family" account

  Scenario: The list is strictly read-only
    Then the all-accounts list offers "Root" no action other than opening an account

  Scenario: An ordinary user has no all-accounts list
    Then "Bob" does not see a link to the all-accounts list on their dashboard
    And "Bob" cannot see the all-accounts list

  Scenario: A guest cannot see the all-accounts list
    Then someone who is not signed in cannot see the all-accounts list

  Scenario: The list grants no membership and changes no dashboard
    Given "Root" is a member of the "Family" account
    Then "Root" sees only the "Family" account on their dashboard
    And "Root" sees the all-accounts list:
      | account |
      | Family  |
      | Office  |
    And "Root" is not a member of the "Office" account
