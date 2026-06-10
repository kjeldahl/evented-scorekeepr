# frozen_string_literal: true

# Leagues slice steps. League helpers (league_ids registry, create_league,
# league_for, close_league_via_ui, ...) live in
# features/support/leagues_world.rb so later slices (matches, scoreboards)
# can reuse the shared phrases ("the X account has an open league Y ...",
# "X closes the Y league").

Given("the {string} account has an open league {string} for {string} " \
      "with starting points {int} and stake {int}%") do |account, league, game_type, points, stake|
  create_league(account_owner_name(account), league, account:, game_type:, starting_points: points, stake:)
end

When("{string} creates a league {string} for {string} in the {string} account") do |actor, league, game_type, account|
  create_league_via_ui(actor, league, account:, game_type:)
end

When("{string} creates a league {string} for {string} in the {string} account " \
     "with starting points {int} and stake {int}%") do |actor, league, game_type, account, points, stake|
  create_league_via_ui(actor, league, account:, game_type:, starting_points: points, stake:)
end

When("{string} attempts to create a league {string} for {string} in the {string} account " \
     "with starting points {int} and stake {int}%") do |actor, league, game_type, account, points, stake|
  attempt_league_creation(actor, league, account:, game_type:, starting_points: points, stake:)
end

Then("the league creation is accepted") do
  league_id = find_league_id(@last_league_name)
  expect(league_id).not_to be_nil
  remember_league(@last_league_name, league_id)
  expect(league_list_entry(@last_league_name)).to be_visible
end

Then("the league creation is rejected because {string}") do |reason|
  expect(page).to have_css(".flash--alert", text: reason)
end

Then("the {string} league has starting points {int} and stake {int}%") do |league_name, points, stake|
  league = league_for(league_name)
  expect(league.starting_points).to eq(points)
  expect(league.stake_percentage).to eq(stake)
end

Then("the {string} league is open") do |league_name|
  expect(league_list_entry(league_name)).to have_no_text("(closed)")
end

Then("the {string} league is closed") do |league_name|
  expect(league_list_entry(league_name)).to have_text("(closed)")
end

When("{string} closes the {string} league") do |actor, league_name|
  close_league_via_ui(actor, league_name)
end
