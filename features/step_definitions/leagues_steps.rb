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

When("{string} renames the {string} league to {string}") do |name, league_name, new_name|
  sign_in(name) unless signed_in_as?(name)
  league = league_for(league_name)
  visit "/accounts/#{league.account_id}/leagues/#{league.id}/edit"
  fill_in "Name", with: new_name
  submit_form "Rename league"
  remember_league(new_name, league.id)
end

When("{string} attempts to rename the {string} league to {string}") do |name, league_name, new_name|
  sign_in(name) unless signed_in_as?(name)
  league = league_for(league_name)
  page.driver.submit :patch, "/accounts/#{league.account_id}/leagues/#{league.id}", { name: new_name }
end

Then("the league rename is accepted") do
  expect(page).to have_css(".flash--notice")
end

Then("the league rename is rejected because {string}") do |reason|
  expect(page).to have_css(".flash--alert", text: reason)
end

Then("the league is shown as {string} on its scoreboard page") do |league_name|
  visit_scoreboard_as_member(league_name)
  expect(page).to have_css("h1", text: league_name)
end

Then("the {string} account lists the league {string}") do |account_name, league_name|
  owner = account_owner_name(account_name)
  sign_in(owner) unless signed_in_as?(owner)
  visit "/accounts/#{account_id_for(account_name)}"
  expect(page).to have_css(".league-list li", text: league_name)
end

Then("the {string} league is a match league") do |league_name|
  league = league_for(league_name)
  event = EventStore.read(DcbEventStore::Query.new([
    DcbEventStore::QueryItem.new(
      event_types: %w[LeagueCreated],
      tags: "league:#{league.id}"
    )
  ])).last
  expect(event.data.fetch(:match_type)).to eq("match")
end

# The feature uses both Given and Then for this phrase; Cucumber treats
# Given/When/Then as synonyms, so having two definitions with the same
# pattern is ambiguous.  We keep the Then variant and add an explicit
# Given variant with a slightly different regex so they don't collide.
When(/^the league "(.*)" is a multiplayer league$/) do |league_name|
  league = league_for(league_name)
  event = EventStore.read(DcbEventStore::Query.new([
    DcbEventStore::QueryItem.new(
      event_types: %w[LeagueCreated],
      tags: "league:#{league.id}"
    )
  ])).last
  expect(event.data.fetch(:match_type)).to eq("multiplayer")
end

Given(/^the "(.*)" league is a multiplayer league$/) do |league_name|
  league = league_for(league_name)
  event = EventStore.read(DcbEventStore::Query.new([
    DcbEventStore::QueryItem.new(
      event_types: %w[LeagueCreated],
      tags: "league:#{league.id}"
    )
  ])).last
  expect(event.data.fetch(:match_type)).to eq("multiplayer")
end

# League creation with explicit match_type (via domain command, not UI —
# the form currently has no match_type selector).
When("{string} creates a league {string} for {string} in the {string} account as a match league") do |actor, league, game_type, account|
  create_league(actor, league, account:, game_type:)
end

When("{string} creates a league {string} for {string} in the {string} account as a multiplayer league") do |actor, league, game_type, account|
  create_multiplayer_league(actor, league, account:, game_type:)
end
