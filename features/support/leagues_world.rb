# frozen_string_literal: true

# League-related world helpers for all slices' step definitions.
#
# Scenarios refer to leagues by name ("Foosball Spring"); the per-scenario
# `league_ids` registry maps those names to league ids so later steps can
# build paths and query read models.
#
# Public helper API (reuse these in other slices' steps):
#   league_ids                          # league name => league_id
#   remember_league(name, league_id)
#   league_id_for(league_name)          # registered id (raises when unknown)
#   league_for(league_name)             # Leagues::League summary (settings + open?/closed?)
#   create_league(creator, name, account:, game_type:, starting_points: 1000, stake: 10)
#                                       # via the domain command + remember
#   find_league_id(league_name)         # newest LeagueCreated with that name (from the event store)
#   create_league_via_ui(actor, name, account:, game_type:, ...)
#   close_league_via_ui(actor, league_name)   # POSTs the close route as the actor
#   account_owner_name(account_name) / owner_name_for(account_id)
#   league_list_entry(league_name)      # the league's row on its account page (signed in as the owner)
module LeaguesWorld
  def league_ids
    @league_ids ||= {}
  end

  def remember_league(name, league_id)
    league_ids[name] = league_id
  end

  def league_id_for(league_name)
    league_ids.fetch(league_name) { raise "unknown league #{league_name.inspect} — create it first" }
  end

  def league_for(league_name)
    Leagues::League.find(league_id_for(league_name))
  end

  def create_league(creator, name, account:, game_type:, starting_points: 1000, stake: 10)
    result = Leagues::CreateLeague.call(
      account_id: account_id_for(account), user_id: user_id_for(creator),
      name:, game_type:, starting_points:, stake_percentage: stake
    )
    raise "could not create league #{name}: #{result.error}" if result.failure?

    remember_league(name, result.value)
    result.value
  end

  # Looks up the id of a league created through the UI (scan LeagueCreated
  # events by name, as the page redirects into the not-yet-built scoreboard).
  def find_league_id(league_name)
    query = DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[LeagueCreated]) ])
    EventStore.read(query).find { |event| event.data[:name] == league_name }&.data&.fetch(:league_id)
  end

  # Creates a league through the real UI form. Leaving starting points and
  # stake nil keeps the form's prefilled defaults (1000 / 10).
  def create_league_via_ui(actor, league_name, account:, game_type:, starting_points: nil, stake: nil)
    @last_league_name = league_name
    sign_in(actor) unless signed_in_as?(actor)
    visit "/accounts/#{account_id_for(account)}/leagues/new"
    fill_in "Name", with: league_name
    fill_in "Game type", with: game_type
    fill_in "Starting points", with: starting_points if starting_points
    fill_in "Stake percentage", with: stake if stake
    submit_form "Create league"
  end

  # POSTs the create route directly: invalid settings re-render the form and
  # a non-member is bounced before ever seeing it, so there is no form to fill.
  def attempt_league_creation(actor, league_name, account:, game_type:, starting_points:, stake:)
    @last_league_name = league_name
    sign_in(actor) unless signed_in_as?(actor)
    submit_post("/accounts/#{account_id_for(account)}/leagues",
                name: league_name, game_type:, starting_points:, stake_percentage: stake)
  end

  def close_league_via_ui(actor, league_name)
    sign_in(actor) unless signed_in_as?(actor)
    league = league_for(league_name)
    submit_post("/accounts/#{league.account_id}/leagues/#{league.id}/close")
  end

  # POSTs directly (the button lives on the not-yet-built scoreboard page)
  # and tolerates a redirect into a missing controller, mirroring the
  # world's submit_form.
  def submit_post(path, params = {})
    page.driver.submit :post, path, params
  rescue ActionDispatch::MissingController, ActionController::RoutingError
    nil
  end

  def account_owner_name(account_name)
    owner_name_for(account_id_for(account_name))
  end

  def owner_name_for(account_id)
    owner_id = account_owner_id(account_id)
    users.keys.find { |name| user_id_for(name) == owner_id } or
      raise "no registered user owns account #{account_id}"
  end

  # The account page (accounts slice) lists each league with a "(closed)"
  # marker; league status is asserted there, signed in as the account owner.
  def league_list_entry(league_name)
    league = league_for(league_name)
    owner = owner_name_for(league.account_id)
    sign_in(owner) unless signed_in_as?(owner)
    visit "/accounts/#{league.account_id}"
    page.find(".league-list li", text: league_name)
  end
end

World(LeaguesWorld)
