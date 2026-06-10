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

  # Formats the league's matches newest first as the features phrase them:
  # the winning side first ("Alice beats Bob 21-8", "Alice and Carol beat
  # Bob and Dave 10-4").
  def recent_match_lines(league_name)
    names = registered_user_names
    match_events(league_name).reverse.map { |event| match_line(event.data, names) }
  end

  def match_line(data, names)
    home, away = data.values_at(:home_player_ids, :away_player_ids)
    home_score, away_score = data.values_at(:home_score, :away_score)
    winners, losers = home_score > away_score ? [ home, away ] : [ away, home ]
    verb = winners.one? ? "beats" : "beat"
    scores = [ home_score, away_score ].sort.reverse.join("-")
    "#{names.values_at(*winners).join(" and ")} #{verb} #{names.values_at(*losers).join(" and ")} #{scores}"
  end

  def registered_user_names
    query = DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[UserRegistered]) ])
    EventStore.read(query).to_h { |event| [ event.data[:user_id], event.data[:name] ] }
  end
end

World(MatchesWorld)
