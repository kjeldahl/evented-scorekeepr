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


# Register with a raw player count — submits via the driver so flash messages render.
When("{string} attempts to register a multiplayer match in {string} with {int} players") do |registrar, league_name, player_count|
  league_record = league_for(league_name)
  sign_in(registrar) unless signed_in_as?(registrar)

  visit new_account_league_match_path(league_record.account_id, league_id_for(league_name))

  members_list = Matches::AccountMembers.for_account(league_record.account_id)
  uids = members_list.map(&:user_id).first(player_count)
  player_names = members_list.map(&:name).first(player_count)

  # Set up the "last attempt" tracking so the rejection step can verify.
  @last_multiplayer_match = { league: league_name, player_names:, scores: Array.new(player_count, "0") }
  @multiplayer_matches_before = multiplayer_match_events(league_name).count

  # Build player_ids and scores for exactly player_count participants.
  scores = uids.to_h { |uid| [ uid, "0" ] }

  post_path = "/accounts/#{league_record.account_id}/leagues/#{league_id_for(league_name)}/matches"
  page.driver.submit :post, post_path, { player_ids: uids, scores: scores }
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

# --- Multiplayer match form steps (multiplayer_match_form.feature) --------

When("{string} opens the multiplayer match form for {string}") do |registrar, league_name|
  league_record = league_for(league_name)
  sign_in(registrar) unless signed_in_as?(registrar)
  visit new_account_league_match_path(league_record.account_id, league_id_for(league_name))
end

Then("the form offers {int} player rows") do |expected_count|
  actual_count = page.all("div.multiplayer-scores table tbody tr").count
  expect(actual_count).to eq(expected_count),
    "expected #{expected_count} rows, found #{actual_count}"
end

Then("every player row offers all {int} members of the {string} account") do |member_count, _account_name|
  page.all("div.multiplayer-scores table tbody tr").each do |row|
    select = row.find("select[name*='player_ids']")
    options = select.all("option").map { |opt| opt.text.strip }.reject { |t| t.empty? || t == "Select player" }
    expect(options.size).to eq(member_count),
      "expected #{member_count} options, found #{options.size}: #{options.inspect}"
  end
end

# Submit the multiplayer form with a mix of filled and empty rows.
# DataTable rows map POSITIONALLY to form rows: row 0 → form row 0, etc.
# If a row names a player, that player is selected and scored.
# If a row has no player but a score, the score is entered without selection.
#
# Because we use the Rack::Test driver (no JavaScript), Capybara form-filling
# helpers cannot modify <select> elements.  Instead we build the params hash
# and submit directly via page.driver.post, which mimics a real form POST.
def submit_multiplayer_form(registrar, league_name, table)
  league_record = league_for(league_name)
  sign_in(registrar) unless signed_in_as?(registrar)

  # Visit the form to establish session and navigate.
  visit new_account_league_match_path(league_record.account_id, league_id_for(league_name))

  # Collect form row info: uid + name for each rendered row.
  members_list = Matches::AccountMembers.for_account(league_record.account_id)
  rows_info = page.all("div.multiplayer-scores table tbody tr").each_with_index.map do |row, idx|
    select_el = row.find("select[name*='player_ids']")
    uid = select_el["data-player-id"]
    name = members_list.find { |m| m.user_id == uid }&.name || ""
    { idx:, uid:, name:, row: }
  end

  # Parse the DataTable.
  table_rows = table.hashes.map do |row|
    { player: row["player"]&.strip, score: row["score"]&.strip }
  end

  # Build form parameters mirroring what the browser would send.
  # We need player_ids[] and scores[] as arrays, one per row.
  player_ids_arr = []
  scores_arr = []

  # First pass: for each DataTable entry with a player, mark it as filled.
  rows_info.each do |info|
    entry = table_rows.find { |t| t[:player] == info[:name] }
    if entry
      if entry[:score] && !entry[:score].empty?
        # Full row: player + score.
        player_ids_arr << info[:uid]
        scores_arr << entry[:score]
      else
        # Half-filled: player selected but no score → send player_id with empty score.
        player_ids_arr << info[:uid]
        scores_arr << ""
      end
    else
      # Empty row: no player, no score.
      player_ids_arr << ""
      scores_arr << ""
    end
  end

  # Second pass: handle DataTable rows with no player but a score.
  table_rows.each_with_index do |entry, i|
    next if entry[:player] && !entry[:player].empty?
    next unless entry[:score] && !entry[:score].empty?

    form_row = rows_info[i]
    next unless form_row
    # Score without player.
    player_ids_arr[i] = ""
    scores_arr[i] = entry[:score]
  end

  # Convert positional arrays to hash { uid => score } for the scores param.
  scores_hash = {}
  rows_info.each_with_index do |info, i|
    scores_hash[info[:uid]] = scores_arr[i] if scores_arr[i] && !scores_arr[i].empty?
  end

  # POST the form data via the driver.
  post_path = "/accounts/#{league_record.account_id}/leagues/#{league_id_for(league_name)}/matches"
  page.driver.submit :post, post_path, { player_ids: player_ids_arr, scores: scores_hash }

  # page.driver.submit updates page.body and page.current_path for the re-render
  # case (flash.now is inlined in the response body).  For the redirect case,
  # page.body is empty; follow the redirect to get the flash into the DOM.
  if page.response_headers["Location"].present?
    visit page.response_headers["Location"]
  end
end

When("{string} registers a multiplayer match in {string} on the form, leaving the other rows empty:") do |registrar, league_name, table|
  submit_multiplayer_form(registrar, league_name, table)
end

When("{string} attempts to register a multiplayer match in {string} on the form, leaving the other rows empty:") do |registrar, league_name, table|
  # Build player_names from the DataTable (entries that name a player) so the
  # event-tracking hash reflects the intended participants (even though the
  # submission will be rejected).
  player_names = table.hashes.filter_map { |row| row["player"]&.strip&.presence }
  @last_multiplayer_match = { league: league_name, player_names:, scores: Array.new(player_names.size, "0") }
  @multiplayer_matches_before = multiplayer_match_events(league_name).count

  submit_multiplayer_form(registrar, league_name, table)
end

# Legacy helpers from earlier Rack::QueryParser experiments — no longer used.
# Kept at the bottom of the file to avoid accidental calls.
#
# def submit_form_encoded(path, query_string)
#   page.driver.post(path, {}, { input: StringIO.new(query_string) })
# end
#
# def build_multiplayer_params(player_ids, scores)
#   parts = player_ids.map { |uid| "player_ids[]=#{CGI.escape(uid)}" }
#   scores.each { |uid, score| parts << "scores[#{CGI.escape(uid)}]=#{CGI.escape(score.to_s)}" }
#   parts.join("&")
# end
