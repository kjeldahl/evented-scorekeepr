# frozen_string_literal: true

# Match-related world helpers for all slices' step definitions. Scenarios
# refer to players and leagues by name; these helpers translate to ids via
# the users/league registries (world.rb, leagues_world.rb).
#
# Public helper API (reuse these in other slices' steps — scoring,
# scoreboards, multi-tenancy):
#   register_match(registrar, league:, home:, away:, home_score:, away_score:, via_ui: true)
#     # home/away are arrays of player display names; registers through the
#     # real form (via_ui: true) or by POSTing raw values (via_ui: false,
#     # for rejection paths where the form is unreachable or unfillable).
#     # Remembers the attempt for the accepted/rejected assertions and
#     # returns true when the match was appended to the event store.
#   register_match!(...)               # same, but raises when not accepted (for Givens)
#   match_events(league_name)          # MatchRegistered events for the league, oldest first
#   last_match_registered?             # did the remembered attempt get stored?
#   recent_match_lines(league_name)    # ["Alice beats Bob 21-8", ...] newest first
module MatchesWorld
  def register_match(registrar, league:, home:, away:, home_score:, away_score:, via_ui: true)
    @last_match = { league:, home:, away:, home_score:, away_score: }
    @matches_before = match_events(league).count
    sign_in(registrar) unless signed_in_as?(registrar)
    if via_ui
      submit_match_form(league, home:, away:, home_score:, away_score:)
    else
      post_match(league, home:, away:, home_score:, away_score:)
    end
    last_match_registered?
  end

  def register_match!(registrar, league:, home:, away:, home_score:, away_score:)
    return if register_match(registrar, league:, home:, away:, home_score:, away_score:)

    raise "match in #{league.inspect} (#{home.join(" and ")} vs #{away.join(" and ")}) was not registered"
  end

  def submit_match_form(league, home:, away:, home_score:, away_score:)
    league_record = league_for(league)
    visit "/accounts/#{league_record.account_id}/leagues/#{league_id_for(league)}/matches/new"
    select home[0], from: "Home player 1"
    select home[1], from: "Home player 2" if home[1]
    select away[0], from: "Away player 1"
    select away[1], from: "Away player 2" if away[1]
    fill_in "Home score", with: home_score
    fill_in "Away score", with: away_score
    submit_form "Register match"
  end

  # POSTs the create route directly with raw values: invalid input re-renders
  # the form and a non-member never sees it, so there is no form to fill.
  def post_match(league, home:, away:, home_score:, away_score:)
    league_record = league_for(league)
    submit_post("/accounts/#{league_record.account_id}/leagues/#{league_id_for(league)}/matches", {
      home_player_1_id: user_id_for(home[0]), home_player_2_id: home[1] && user_id_for(home[1]),
      away_player_1_id: user_id_for(away[0]), away_player_2_id: away[1] && user_id_for(away[1]),
      home_score:, away_score:
    }.compact)
  end

  def match_events(league_name)
    query = DcbEventStore::Query.new([
      DcbEventStore::QueryItem.new(event_types: %w[MatchRegistered], tags: [ "league:#{league_id_for(league_name)}" ])
    ])
    EventStore.read(query)
  end

  # The MatchRegistered event from the most recent registration attempt (for
  # asserting who a match was attributed to).
  def last_registered_match_event
    match_events(last_match_attempt[:league]).last or
      raise "no match was registered in #{last_match_attempt[:league].inspect}"
  end

  def last_match_registered?
    expected = last_match_attempt
    match_events(expected[:league]).any? { |event| event_matches_attempt?(event, expected) }
  end

  def last_match_attempt
    @last_match or raise "no match registration was attempted yet"
  end

  def matches_registered_during_last_attempt
    match_events(last_match_attempt[:league]).count - @matches_before
  end

  def event_matches_attempt?(event, expected)
    event.data[:home_player_ids] == expected[:home].map { |name| user_id_for(name) } &&
      event.data[:away_player_ids] == expected[:away].map { |name| user_id_for(name) } &&
      event.data[:home_score] == expected[:home_score].to_i &&
      event.data[:away_score] == expected[:away_score].to_i
  end

  # The recent-matches list as the league page renders it, newest first
  # ("Alice beats Bob 21-8", "Alice and Carol beat Bob and Dave 10-4"). Only
  # the match line is read, so a match's edit link does not leak into it.
  def recent_match_lines(league_name)
    visit_scoreboard_as_member(league_name)
    page.all("ol.recent-matches li .match-line").map { |item| item.text.strip }
  end

  # --- Editing matches ---------------------------------------------------
  #   edit_match!(editor, league:, winners:, losers:, winner_score:,
  #               loser_score:, new_winners:, new_losers:, new_winner_score:,
  #               new_loser_score:)  # corrects a match through the edit form
  #   attempt_edit(editor, league:, winners:, losers:, winner_score:,
  #                loser_score:, home_score:, away_score:)  # raw PATCH (rejections)
  #   edit_match_path(league_name, match_id)  # the edit-form path (link assertions)
  #   corrections_after_last_edit_attempt     # corrections stored since the attempt

  def edit_match!(editor, league:, winners:, losers:, winner_score:, loser_score:,
                  new_winners:, new_losers:, new_winner_score:, new_loser_score:)
    event = find_registered_match(league, winners:, losers:, winner_score:, loser_score:)
    home_score, away_score = corrected_scores(event, new_winners:, new_winner_score:, new_loser_score:)
    sign_in(editor) unless signed_in_as?(editor)
    visit edit_match_path(league, event.data.fetch(:match_id))
    fill_in "Home score", with: home_score
    fill_in "Away score", with: away_score
    submit_form "Save match"
  end

  def attempt_edit(editor, league:, winners:, losers:, winner_score:, loser_score:, home_score:, away_score:)
    event = find_registered_match(league, winners:, losers:, winner_score:, loser_score:)
    @last_edit = { league:, match_id: event.data.fetch(:match_id) }
    @corrections_before = correction_events(league).count
    sign_in(editor) unless signed_in_as?(editor)
    league_record = league_for(league)
    submit_patch("/accounts/#{league_record.account_id}/leagues/#{league_id_for(league)}/matches/#{@last_edit[:match_id]}",
                 { home_score:, away_score: })
  end

  def edit_match_path(league_name, match_id)
    league_record = league_for(league_name)
    "/accounts/#{league_record.account_id}/leagues/#{league_id_for(league_name)}/matches/#{match_id}/edit"
  end

  def corrections_after_last_edit_attempt
    correction_events(@last_edit.fetch(:league)).count - @corrections_before
  end

  # The registered match whose winning side and score match the description.
  def find_registered_match(league_name, winners:, losers:, winner_score:, loser_score:)
    winner_ids = winners.map { |name| user_id_for(name) }
    loser_ids = losers.map { |name| user_id_for(name) }
    match_events(league_name).find { |event| winning_side(event) == [ winner_ids, loser_ids, winner_score, loser_score ] } or
      raise "no registered match #{winners.join(" and ")} beat #{losers.join(" and ")} #{winner_score}-#{loser_score} in #{league_name.inspect}"
  end

  # The new home/away scores for a correction: the winning side keeps its
  # fixed home/away position, so the new winner score goes to whichever side
  # the winners are on.
  def corrected_scores(event, new_winners:, new_winner_score:, new_loser_score:)
    home_ids = event.data.fetch(:home_player_ids)
    new_winner_ids = new_winners.map { |name| user_id_for(name) }
    if new_winner_ids.sort == home_ids.sort
      [ new_winner_score, new_loser_score ]
    else
      [ new_loser_score, new_winner_score ]
    end
  end

  def winning_side(event)
    data = event.data
    home_win = data.fetch(:home_score) > data.fetch(:away_score)
    winners = home_win ? data.fetch(:home_player_ids) : data.fetch(:away_player_ids)
    losers = home_win ? data.fetch(:away_player_ids) : data.fetch(:home_player_ids)
    [ winners, losers, (home_win ? data.fetch(:home_score) : data.fetch(:away_score)),
      (home_win ? data.fetch(:away_score) : data.fetch(:home_score)) ]
  end

  def correction_events(league_name)
    query = DcbEventStore::Query.new([
      DcbEventStore::QueryItem.new(event_types: %w[MatchResultCorrected], tags: [ "league:#{league_id_for(league_name)}" ])
    ])
    EventStore.read(query)
  end

  def submit_patch(path, params = {})
    page.driver.submit :patch, path, params
  rescue ActionDispatch::MissingController, ActionController::RoutingError
    nil
  end

  # --- Deleting matches --------------------------------------------------
  #   delete_match!(deleter, league:, winners:, losers:, winner_score:,
  #                 loser_score:)  # deletes through the edit form's button
  #   attempt_delete(deleter, league:, winners:, losers:, winner_score:,
  #                  loser_score:)  # raw DELETE (rejection paths)
  #   deletions_after_last_delete_attempt  # deletions stored since the attempt

  def delete_match!(deleter, league:, winners:, losers:, winner_score:, loser_score:)
    event = find_registered_match(league, winners:, losers:, winner_score:, loser_score:)
    sign_in(deleter) unless signed_in_as?(deleter)
    visit edit_match_path(league, event.data.fetch(:match_id))
    submit_form "Delete match"
  end

  def attempt_delete(deleter, league:, winners:, losers:, winner_score:, loser_score:)
    event = find_registered_match(league, winners:, losers:, winner_score:, loser_score:)
    @last_delete = { league:, match_id: event.data.fetch(:match_id) }
    @deletions_before = deletion_events(league).count
    sign_in(deleter) unless signed_in_as?(deleter)
    league_record = league_for(league)
    submit_delete("/accounts/#{league_record.account_id}/leagues/#{league_id_for(league)}/matches/#{@last_delete[:match_id]}")
  end

  def deletions_after_last_delete_attempt
    deletion_events(@last_delete.fetch(:league)).count - @deletions_before
  end

  def deletion_events(league_name)
    query = DcbEventStore::Query.new([
      DcbEventStore::QueryItem.new(event_types: %w[MatchDeleted], tags: [ "league:#{league_id_for(league_name)}" ])
    ])
    EventStore.read(query)
  end

  def submit_delete(path, params = {})
    page.driver.submit :delete, path, params
  rescue ActionDispatch::MissingController, ActionController::RoutingError
    nil
  end
end

  # --- Multiplayer matches -------------------------------------------------
  #   register_multiplayer_match(registrar, league, player_names, scores; via_ui:)
  #     # Registers a multiplayer match through the UI (via_ui: true) or raw POST.
  #     # player_names / scores are arrays of display names / numeric scores.
  #   register_multiplayer_match!(...)  # same, but raises on failure
  #   correct_multiplayer_match(editor, league, player_names, scores; via_ui:)
  #     # Corrects a multiplayer match through the UI or raw PATCH.
  #   correct_multiplayer_match!(...)  # same, but raises on failure
  #   delete_multiplayer_match(deleter, league; via_ui:)
  #     # Deletes a multiplayer match through the UI or raw DELETE.
  #   delete_multiplayer_match!(...)  # same, but raises on failure

  def last_multiplayer_league
    @last_multiplayer_league or raise "no multiplayer league created yet"
  end

  def register_multiplayer_match(registrar, league, player_names, scores, via_ui: true)
    scores = scores.map { |s| s.is_a?(String) ? s : s.to_s }
    @last_multiplayer_match = { league:, player_names:, scores: }
    @multiplayer_matches_before = multiplayer_match_events(league).count
    sign_in(registrar) unless signed_in_as?(registrar)
    if via_ui
      submit_multiplayer_match_form(league, player_names:, scores:)
    else
      post_multiplayer_match(league, player_names:, scores:)
    end
    last_multiplayer_match_registered?
  end

  def register_multiplayer_match!(registrar, league, player_names, scores)
    return if register_multiplayer_match(registrar, league, player_names, scores)
    raise "multiplayer match in #{league.inspect} (#{player_names.join(" and ")}) was not registered"
  end

  def submit_multiplayer_match_form(league, player_names:, scores:)
    post_multiplayer_match(league, player_names:, scores:)
  end

  def post_multiplayer_match(league, player_names:, scores:)
    player_ids = player_names.map { |n| user_id_for(n) }
    scores_hash = player_ids.each_with_index.to_h { |uid, i| [ uid, scores[i] ] }
    params = { "player_ids" => player_ids, "scores" => scores_hash }
    submit_post("/accounts/#{league_for(league).account_id}/leagues/#{league_id_for(league)}/matches", params)
  end

  def last_multiplayer_match_registered?
    expected = last_multiplayer_match
    multiplayer_match_events(expected[:league]).any? do |event|
      player_ids = event.data.fetch(:player_ids)
      expected[:player_names].map { |name| user_id_for(name) } == player_ids
    end
  end

  def last_multiplayer_match
    @last_multiplayer_match or raise "no multiplayer match registration attempted yet"
  end

  def multiplayer_matches_registered_during_last_attempt
    multiplayer_match_events(last_multiplayer_match[:league]).count - @multiplayer_matches_before
  end

  def correct_multiplayer_match(editor, league, player_names, scores, via_ui: true)
    scores = scores.map { |s| s.is_a?(String) ? s : s.to_s }
    @last_multiplayer_correction = { league:, player_names:, scores: }
    @multiplayer_corrections_before = multiplayer_correction_events(league).count
    sign_in(editor) unless signed_in_as?(editor)
    if via_ui
      submit_multiplayer_correction_form(league, player_names:, scores:)
    else
      patch_multiplayer_correction(league, player_names:, scores:)
    end
  end

  def correct_multiplayer_match!(editor, league, player_names, scores)
    correct_multiplayer_match(editor, league, player_names, scores)
  end

  def submit_multiplayer_correction_form(league, player_names:, scores:)
    league_record = league_for(league)
    match_event = multiplayer_match_events(league).last or
      raise "no multiplayer match found in #{league.inspect}"
    match_id = match_event.data.fetch(:match_id)
    visit "/accounts/#{league_record.account_id}/leagues/#{league_id_for(league)}/matches/#{match_id}/edit"
    # The multiplayer edit form uses scores[player_id] number inputs.
    # Capybara's fill_in does not handle bracketed names on number inputs
    # reliably, so we set the value directly.
    player_names.zip(scores).each do |(name, score)|
      uid = user_id_for(name)
      find("input[name=\"scores[#{uid}]\"]").set(score)
    end
    submit_form "Save match"
  end

  def patch_multiplayer_correction(league, player_names:, scores:)
    league_record = league_for(league)
    match_event = multiplayer_match_events(league).last or
      raise "no multiplayer match found in #{league.inspect}"
    match_id = match_event.data.fetch(:match_id)
    player_ids = player_names.map { |n| user_id_for(n) }
    scores_hash = player_ids.each_with_index.to_h { |uid, i| [ uid, scores[i] ] }
    params = { "player_ids" => player_ids, "scores" => scores_hash }
    submit_patch("/accounts/#{league_record.account_id}/leagues/#{league_id_for(league)}/matches/#{match_id}",
                 params)
  end

  def multiplayer_corrections_after_last_correction_attempt
    multiplayer_correction_events(@last_multiplayer_correction.fetch(:league)).count - @multiplayer_corrections_before
  end

  def delete_multiplayer_match(deleter, league, via_ui: true)
    @last_multiplayer_delete = { league: }
    @multiplayer_deletions_before = multiplayer_deletion_events(league).count
    sign_in(deleter) unless signed_in_as?(deleter)
    if via_ui
      submit_multiplayer_delete_form(league)
    else
      raw_delete_multiplayer_match(league)
    end
  end

  def delete_multiplayer_match!(deleter, league)
    delete_multiplayer_match(deleter, league)
  end

  def submit_multiplayer_delete_form(league)
    league_record = league_for(league)
    match_event = multiplayer_match_events(league).last or
      raise "no multiplayer match found in #{league.inspect}"
    match_id = match_event.data.fetch(:match_id)
    visit "/accounts/#{league_record.account_id}/leagues/#{league_id_for(league)}/matches/#{match_id}/edit"
    submit_form "Delete match"
  end

  def raw_delete_multiplayer_match(league)
    league_record = league_for(league)
    match_event = multiplayer_match_events(league).last or
      raise "no multiplayer match found in #{league.inspect}"
    match_id = match_event.data.fetch(:match_id)
    submit_delete("/accounts/#{league_record.account_id}/leagues/#{league_id_for(league)}/matches/#{match_id}")
  end

  def multiplayer_deletions_after_last_delete_attempt
    multiplayer_deletion_events(@last_multiplayer_delete.fetch(:league)).count - @multiplayer_deletions_before
  end

  def attempt_multiplayer_registration(registrar, league, player_names, scores, via_ui: false)
    register_multiplayer_match(registrar, league, player_names, scores, via_ui:)
  end

World(MatchesWorld)
