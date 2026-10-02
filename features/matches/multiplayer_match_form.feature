@wip
Feature: Multiplayer match registration form
  Only some of an account's players take part in any given multiplayer
  match, so the registration form must let the registrar choose who played.
  The form offers a fixed set of player rows: each row is a picker listing
  every account member, plus that player's score. The registrar fills one
  row per participant and leaves the rest empty; an empty row is ignored, so
  the match is registered for exactly the players picked.

  The form offers as many rows as the game type allows players, capped at
  the number of members there are to pick from — there is never a row that
  could not legally be filled, and never fewer rows than the members
  available up to that limit.

  A half-filled row is a mistake, not a participant: a row with a player but
  no score, or a score but no player, is rejected rather than silently
  dropped. The scores themselves, the player count and the resulting points
  are specified in "Register a multiplayer match"; this feature covers only
  choosing the participants.

  Background:
    Given "Alice" is a registered user with email "alice@example.com" and password "secret123"
    And "Bob" is a registered user with email "bob@example.com" and password "secret123"
    And "Carol" is a registered user with email "carol@example.com" and password "secret123"
    And "Dave" is a registered user with email "dave@example.com" and password "secret123"
    And "Eve" is a registered user with email "eve@example.com" and password "secret123"
    And "Alice" owns the "Office" account
    And "Bob" is a member of the "Office" account
    And "Carol" is a member of the "Office" account
    And "Dave" is a member of the "Office" account
    And "Eve" is a member of the "Office" account
    And the "Office" account has an open league "Golf Cup" for "Golf" as a multiplayer league with starting points 1000 and stake 10%

  # multiplayer_match_form-1
  Scenario Outline: The form offers one row per possible participant
    # The account has 5 members. Golf allows up to 8, so the member count is
    # the limit; Foosball allows up to 4, so the game type is.
    Given the "Office" account has an open league "Club Night" for "<game type>" as a multiplayer league with starting points 1000 and stake 10%
    When "Alice" opens the multiplayer match form for "Club Night"
    Then the form offers <rows> player rows
    And every player row offers all 5 members of the "Office" account

    Examples:
      | game type | rows |
      | Golf      | 5    |
      | Foosball  | 4    |

  # multiplayer_match_form-2
  Scenario: Only the players picked take part in the match
    # The scoring is the 3-player Golf case: Bob 0 is 1st and stakes nothing,
    # Alice 5 is 2nd (stakes 37), Carol 10 is 3rd (stakes 62); Bob takes the
    # pot of 99. Dave and Eve were left out and never enter the standings.
    When "Alice" registers a multiplayer match in "Golf Cup" on the form, leaving the other rows empty:
      | player | score |
      | Bob    | 0     |
      | Alice  | 5     |
      | Carol  | 10    |
    Then "Bob" has 1099 points in "Golf Cup"
    And "Alice" has 963 points in "Golf Cup"
    And "Carol" has 938 points in "Golf Cup"
    And "Dave" is not listed in the "Golf Cup" standings
    And "Eve" is not listed in the "Golf Cup" standings

  # multiplayer_match_form-3
  Scenario Outline: A half-filled row is rejected
    When "Alice" attempts to register a multiplayer match in "Golf Cup" on the form, leaving the other rows empty:
      | player   | score   |
      | Alice    | 5       |
      | <player> | <score> |
    Then the registration is rejected because "<reason>"

    Examples:
      | player | score | reason                      |
      | Bob    |       | every player needs a score  |
      |        | 10    | every score needs a player  |
