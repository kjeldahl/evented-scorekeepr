# frozen_string_literal: true

BARE_NUM = /[-+]?\d+(?:\.\d+)?/
QUOTED_NAME = /"([^"]+)"/

# Multiplayer match step definitions.
#
# These steps cover the new multiplayer domain (N-player matches, proportional
# stake distribution). Helpers live here and reuse the shared world modules.
#
# Note: Gherkin's {int} and {float} patterns both match integer tokens
# (e.g. "10" matches both). To avoid ambiguity, register/correct steps use
# {int} only (happy path) or {string} for the validation paths that need
# actual float literals like "10.5".

# --- League creation for multiplayer leagues -------------------------------

When("the {string} account has an open league {string} for {string} " \
     "as a multiplayer league with starting points {int} and stake {int}%") \
  do |account, league, game_type, points, stake|
  create_multiplayer_league(account_owner_name(account), league, account:, game_type:,
                           starting_points: points, stake:)
end

# --- Register multiplayer matches (via UI and direct POST) ----------------

When("{string} registers a multiplayer match in {string} where {string} scores {int}") \
  do |registrar, league, p1, s1|
  register_multiplayer_match!(registrar, league, [ p1 ], [ s1.to_i ])
end

When("{string} registers a multiplayer match in {string} " \
     "where {string} scores {int}, {string} scores {int}") \
  do |registrar, league, p1, s1, p2, s2|
  register_multiplayer_match!(registrar, league, [ p1, p2 ], [ s1.to_i, s2.to_i ])
end

When("{string} registers a multiplayer match in {string} " \
     "where {string} scores {int}, {string} scores {int}, and {string} scores {int}") \
  do |registrar, league, p1, s1, p2, s2, p3, s3|
  register_multiplayer_match!(registrar, league, [ p1, p2, p3 ], [ s1.to_i, s2.to_i, s3.to_i ])
end

# Uses {string} (not {int}/{float}) because Cucumber cannot distinguish
# integer tokens from float tokens — "2" matches both patterns, causing
# ambiguity.  Validation of integer-only scores is handled by the command.
When("{string} attempts to register a multiplayer match in {string} " \
     "where {string} scores {string} and {string} scores {string}") \
  do |registrar, league, p1, score1, p2, score2|
  register_multiplayer_match(registrar, league, [ p1, p2 ], [ score1, score2 ], via_ui: false)
end

When(/^#{QUOTED_NAME} attempts to register a multiplayer match in #{QUOTED_NAME} where #{QUOTED_NAME} scores (#{BARE_NUM}) and #{QUOTED_NAME} scores (#{BARE_NUM})$/) do |registrar, league, p1, score1, p2, score2|
  register_multiplayer_match(registrar, league, [ p1, p2 ], [ score1, score2 ], via_ui: false)
end

When("{string} attempts to register a multiplayer match in {string} with fewer than {int} players") \
  do |registrar, league, min_players|
  attempt_multiplayer_registration(registrar, league, [], [], via_ui: false)
end


# Deletion step — delete the first (oldest) multiplayer match in the league
When("{string} deletes the first match") do |deleter|
  league = last_multiplayer_league
  league_record = league_for(league)
  match_event = multiplayer_match_events(league).first or
    raise "no multiplayer match found in #{league.inspect}"
  match_id = match_event.data.fetch(:match_id)
  sign_in(deleter) unless signed_in_as?(deleter)
  submit_delete("/accounts/#{league_record.account_id}/leagues/#{league_id_for(league)}/matches/#{match_id}")
end

# --- Registration Givens ------------------------------------------------

Given("{string} has already registered a multiplayer match in {string} " \
      "where {string} scores {int}, {string} scores {int}, and {string} scores {int}") \
  do |registrar, league, p1, s1, p2, s2, p3, s3|
  register_multiplayer_match!(registrar, league, [ p1, p2, p3 ], [ s1.to_i, s2.to_i, s3.to_i ])
end

Given("{string} has registered a multiplayer match in {string} " \
      "where {string} scores {int}, {string} scores {int}, and {string} scores {int}") \
  do |registrar, league, p1, s1, p2, s2, p3, s3|
  register_multiplayer_match!(registrar, league, [ p1, p2, p3 ], [ s1.to_i, s2.to_i, s3.to_i ])
end

# --- Correction steps ----------------------------------------------------
# Use {string} for scores so {int} and {float} patterns don't create ambiguity.
# Integer scores like "2" match {string} fine; floats like "7.5" also match {string}.

When("{string} corrects the match where {string} scores {int}, {string} scores {int}, and {string} scores {int}") \
  do |editor, p1, s1, p2, s2, p3, s3|
  # Use direct PATCH to avoid form-filling ambiguity with bracketed input names
  correct_multiplayer_match(editor, last_multiplayer_league, [ p1, p2, p3 ],
                           [ s1.to_s, s2.to_s, s3.to_s ], via_ui: false)
end

When("{string} corrects the match where {string} scores {int} and {string} scores {int}") \
  do |editor, p1, s1, p2, s2|
  correct_multiplayer_match!(editor, last_multiplayer_league, [ p1, p2 ], [ s1, s2 ])
end

# Uses raw regex to match bare numbers (int or float), avoiding {int}/{float}
# ambiguity since Cucumber treats "2" as matching both patterns.
# Validation of integer-only scores is handled by the command.
When(/^#{QUOTED_NAME} attempts to correct the match where #{QUOTED_NAME} scores (#{BARE_NUM}) and #{QUOTED_NAME} scores (#{BARE_NUM})$/) do |editor, p1, s1, p2, s2|
  correct_multiplayer_match(editor, last_multiplayer_league, [ p1, p2 ], [ s1, s2 ], via_ui: false)
end

# Note: the Given variant of "corrects the match..." uses When pattern
# (Cucumber treats identical patterns with different keywords as ambiguous).

# --- Deletion steps ------------------------------------------------------

When("{string} deletes the match") do |deleter|
  delete_multiplayer_match!(deleter, last_multiplayer_league)
end

When("{string} attempts to delete the match") do |deleter|
  delete_multiplayer_match(deleter, last_multiplayer_league, via_ui: false)
end

# --- Result assertions ---------------------------------------------------

Then("the registration is accepted") do
  expect(last_multiplayer_match_registered?).to be(true)
end

Then("the registration is rejected because {string}") do |reason|
  expect(page).to have_css(".flash--alert", text: reason)
  expect(multiplayer_matches_registered_during_last_attempt).to eq(0)
end

Then("the correction is accepted") do
  expect(multiplayer_corrections_after_last_correction_attempt).to be >= 1
end

Then("the correction is rejected because {string}") do |reason|
  expect(page).to have_css(".flash--alert", text: reason)
  expect(multiplayer_corrections_after_last_correction_attempt).to eq(0)
end

Then("the deletion is accepted") do
  expect(multiplayer_deletions_after_last_delete_attempt).to be >= 1
end

Then("the deletion is rejected because {string}") do |reason|
  expect(page).to have_css(".flash--alert", text: reason)
  expect(multiplayer_deletions_after_last_delete_attempt).to eq(0)
end

Then("{string} is not listed in the {string} standings") do |player, league|
  visit_scoreboard_as_member(league)
  expect(page).not_to have_css("table.scoreboard td", text: player)
end

# --- Multiplayer match events query (for assertions on event data) -------

def multiplayer_match_events(league_name)
  query = DcbEventStore::Query.new([
    DcbEventStore::QueryItem.new(
      event_types: %w[MultiplayerMatchRegistered],
      tags: [ "league:#{league_id_for(league_name)}" ]
    )
  ])
  EventStore.read(query)
end

def multiplayer_correction_events(league_name)
  query = DcbEventStore::Query.new([
    DcbEventStore::QueryItem.new(
      event_types: %w[MultiplayerMatchResultCorrected],
      tags: [ "league:#{league_id_for(league_name)}" ]
    )
  ])
  EventStore.read(query)
end

def multiplayer_deletion_events(league_name)
  query = DcbEventStore::Query.new([
    DcbEventStore::QueryItem.new(
      event_types: %w[MultiplayerMatchDeleted],
      tags: [ "league:#{league_id_for(league_name)}" ]
    )
  ])
  EventStore.read(query)
end
