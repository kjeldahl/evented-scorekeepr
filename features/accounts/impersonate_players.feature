Feature: Impersonate players
  A super admin can impersonate a member of an account and act as that
  member — a deliberate, audited extension of super admin, which is
  otherwise strictly read-only. Impersonation is started from an
  "Impersonate" button on each member row of an account's members list;
  that button is shown only to a super admin, never to an ordinary member.

  While impersonation is in effect the super admin becomes that member for
  the whole session: every page they visit shows a clear notification of
  who they are impersonating with a "Stop impersonating" button next to it,
  and every action they take is performed with the member's privileges and
  attributed to the member (not to the super admin). Pressing the escape
  button ends impersonation and returns the super admin to their own
  identity.

  Everything done under impersonation is recorded in an audit trail: the
  start and end of the impersonation session and every write performed while
  it is in effect, each tied back to the real super admin behind it. There
  is no in-app page for viewing the audit trail yet; only the record is
  required.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Carol" is a registered user with email "carol@example.com" and password "secret123"
    And "Root" is a registered user with email "root@example.com" and password "secret123"
    And "Root" is a super admin
    And "Alice" owns the "Office" account
    And "Bob" is a member of the "Office" account
    And the "Office" account has an open league "Office Foosball" for "Foosball" with starting points 1000 and stake 10%

  # impersonate_players-1
  Scenario: The impersonate button appears on the members list only for a super admin
    Then "Root" sees an impersonate button for the member "Bob" in the "Office" account
    But "Alice" sees no impersonate button in the "Office" account

  # impersonate_players-2
  Scenario: Starting impersonation shows a clear notification with an escape button
    When "Root" impersonates the member "Bob" in the "Office" account
    Then "Root" sees a notice that they are impersonating "Bob"
    And "Root" sees a button to stop impersonating

  # impersonate_players-3
  Scenario: The escape button ends impersonation and restores the super admin's own identity
    Given "Root" impersonates the member "Bob" in the "Office" account
    When "Root" stops impersonating
    Then "Root" sees no impersonation notice
    # Back to being a super admin, who is read-only and not a member:
    And "Root" attempts to register a match in "Office Foosball" where "Alice" beats "Bob" 21-8
    Then the match is rejected because "only members can register matches"

  # impersonate_players-4
  Scenario: While impersonating a member the super admin can do what only that member could
    # As themselves a super admin may not register a match; impersonating Bob,
    # a member, the write goes through and is attributed to Bob.
    Given "Root" impersonates the member "Bob" in the "Office" account
    When "Root" registers a match in "Office Foosball" where "Bob" beats "Alice" 21-8
    Then the match is accepted
    And the "Office Foosball" scoreboard shows:
      | rank | player | points | played | won | lost | streak |
      | 1    | Bob    | 1100   | 1      | 1   | 0    | W1     |
      | 2    | Alice  | 900    | 1      | 0   | 1    | L1     |
    And the match was registered by "Bob"

  # impersonate_players-5
  Scenario: Impersonation is a whole-session identity, effective in the member's other accounts too
    Given "Carol" owns the "Family" account
    And "Bob" is a member of the "Family" account
    And the "Family" account has an open league "Family Foosball" for "Foosball" with starting points 1000 and stake 10%
    And "Root" impersonates the member "Bob" in the "Office" account
    When "Root" registers a match in "Family Foosball" where "Bob" beats "Carol" 21-8
    Then the match is accepted
    And the match was registered by "Bob"
    And "Root" still sees a notice that they are impersonating "Bob"

  # impersonate_players-6
  Scenario: An ordinary member cannot start impersonation
    When "Alice" attempts to impersonate the member "Bob" in the "Office" account
    Then the impersonation is rejected because "only super admins can impersonate players"

  # impersonate_players-7
  Scenario: The audit trail records the session and every action taken while impersonating
    Given "Root" impersonates the member "Bob" in the "Office" account
    And "Root" registers a match in "Office Foosball" where "Bob" beats "Alice" 21-8
    When "Root" stops impersonating
    Then the audit trail records that "Root" started impersonating "Bob"
    And the audit trail records that "Root" impersonating "Bob" registered a match in "Office Foosball"
    And the audit trail records that "Root" stopped impersonating "Bob"

  # impersonate_players-8
  Scenario: A super admin who is also a member sees no impersonate button on their own row
    Given "Root" is a member of the "Office" account
    Then "Root" sees an impersonate button for the member "Bob" in the "Office" account
    But "Root" sees no impersonate button for the member "Root" in the "Office" account

  # impersonate_players-9
  Scenario: Signing out while impersonating clears impersonation and signs the super admin out
    # Sign out ends the super admin's own login, so it must also clear the
    # impersonation session. Otherwise the layout still tries to render the
    # impersonation notice for a signed-out (nil) user and the page crashes.
    Given "Root" impersonates the member "Bob" in the "Office" account
    When "Root" signs out
    Then "Root" is not signed in
    And "Root" sees the sign-in form
    And "Root" sees no impersonation notice

  # impersonate_players-10
  Scenario: Signing out ends the impersonation session in the audit trail
    # Ending impersonation by signing out is still ending it, so the audit
    # trail stays complete: the session's start is paired with an end.
    Given "Root" impersonates the member "Bob" in the "Office" account
    When "Root" signs out
    Then the audit trail records that "Root" started impersonating "Bob"
    And the audit trail records that "Root" stopped impersonating "Bob"
