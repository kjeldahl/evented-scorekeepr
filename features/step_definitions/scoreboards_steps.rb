# frozen_string_literal: true

# Scoreboards slice steps. Scoreboard helpers (visit_scoreboard_as,
# scoreboard_rows, expect_scoreboard, ...) live in
# features/support/scoreboards_world.rb. Points and standings are asserted
# against the rendered scoreboard page, viewed by the account owner (always
# a member); visibility steps view as the named user.

Then("{string} has {int} points in {string}") do |player, points, league|
  visit_scoreboard_as_member(league)
  expect(scoreboard_cell(player, "points")).to eq(points.to_s)
end

Then("the {string} scoreboard shows:") do |league, table|
  visit_scoreboard_as_member(league)
  expect_scoreboard(table)
end

Then("the {string} scoreboard statistics show:") do |league, table|
  visit_scoreboard_as_member(league)
  expect_scoreboard(table)
end

Then("the {string} scoreboard shows no players") do |league|
  visit_scoreboard_as_member(league)
  expect(page).to have_no_css("table.scoreboard tbody tr")
  expect(page).to have_text("No matches yet — register the first one")
end

Then("{string} does not appear on the {string} scoreboard") do |player, league|
  visit_scoreboard_as_member(league)
  expect(scoreboard_players).not_to include(player)
end

# The scoreboard page is the league page (docs/ARCHITECTURE.md), so the
# visibility phrases land there: an allowed viewer (member or super admin)
# stays on the page and sees the league's name and its standings section.
Then("{string} can see the {string} league") do |viewer, league|
  visit_scoreboard_as(viewer, league)
  expect(page).to have_no_css(".flash--alert")
  expect(page).to have_css("h1", text: league)
end

Then("{string} can see the scoreboard of {string}") do |viewer, league|
  visit_scoreboard_as(viewer, league)
  record = league_for(league)
  expect(page).to have_current_path("/accounts/#{record.account_id}/leagues/#{record.id}/scoreboard")
  expect(page).to have_no_css(".flash--alert")
  expect(page).to have_css("h2", text: "Standings")
end

# A refused viewer is bounced to the dashboard with an alert and never sees
# the league's name or its standings.
Then("{string} cannot see the {string} league") do |viewer, league|
  visit_scoreboard_as(viewer, league)
  expect(page).to have_current_path("/")
  expect(page).to have_css(".flash--alert")
  expect(page).to have_no_css("h1", text: league)
end

Then("{string} cannot see the scoreboard of {string}") do |viewer, league|
  visit_scoreboard_as(viewer, league)
  expect(page).to have_current_path("/")
  expect(page).to have_css(".flash--alert")
  expect(page).to have_no_css("table.scoreboard")
end

# --- TV dashboard (features/scoreboards/tv_mode.feature) -------------------
# TV helpers (visit_tv_as, tv_rows, tv_recent_matches, tv_version_as, ...)
# live in features/support/scoreboards_world.rb.

When("{string} opens the TV dashboard for the {string} league") do |viewer, league|
  visit_tv_as(viewer, league)
end

When("{string} follows the TV mode link on the {string} scoreboard") do |viewer, league|
  visit_scoreboard_as(viewer, league)
  click_link "TV mode"
end

Then("the TV dashboard shows the league name {string} and game type {string}") do |name, game_type|
  expect(page).to have_css(".tv-header h1", text: name)
  expect(page).to have_css(".tv-header .tv-game", text: game_type)
end

Then("the TV dashboard standings show:") do |table|
  expect_table_rows(tv_rows, table)
end

Then("the TV dashboard shows no players in the standings") do
  expect(page).to have_no_css(".tv-standings tbody tr")
  expect(page).to have_css(".tv-standings .empty-state")
end

Then("the TV dashboard shows the leader spotlight for {string} with {int} points") do |player, points|
  expect(page).to have_css(".tv-leader", text: player)
  expect(page).to have_css(".tv-leader", text: "#{points} points")
end

Then("the TV dashboard shows no leader spotlight") do
  expect(page).to have_no_css(".tv-leader")
end

Then("the TV dashboard shows the hot-streak spotlight {string}") do |text|
  expect(page).to have_css(".tv-streak", text:)
end

Then("the TV dashboard shows no hot-streak spotlight") do
  expect(page).to have_no_css(".tv-streak")
end

Then("the TV dashboard recent matches show:") do |table|
  expect(tv_recent_matches).to eq(table.hashes.map { |row| row.fetch("match") })
end

Then("the TV dashboard shows no recent matches") do
  expect(page).to have_no_css(".tv-recent li")
  expect(page).to have_css(".tv-recent .empty-state")
end

# The live-update contract: remember the version the viewer saw and how many
# broadcasts the league's stream had carried, then assert the endpoint reports
# a strictly greater version / a new broadcast arrived after the change.
Given("{string} is watching the TV dashboard for the {string} league") do |viewer, league|
  @tv_viewer = viewer
  @tv_version_before = tv_version_as(viewer, league)
  @tv_broadcasts_before = tv_stream_broadcasts(league).size
end

Then("the TV dashboard for {string} reports a newer version") do |league|
  expect(tv_version_as(@tv_viewer, league)).to be > @tv_version_before
end

# The test cable adapter records every broadcast; a new entry on the league's
# "events:league:{id}" stream is the live update pushed to watching TVs.
Then("a live update is pushed to the {string} TV dashboard") do |league|
  broadcasts = tv_stream_broadcasts(league)
  expect(broadcasts.size).to be > @tv_broadcasts_before
  expect(JSON.parse(broadcasts.last)).to eq("type" => "MatchRegistered")
end

Then("{string} can see the TV dashboard for the {string} league") do |viewer, league|
  visit_tv_as(viewer, league)
  expect(page).to have_no_css(".flash--alert")
  expect(page).to have_css(".tv-header h1", text: league)
end

When("{string} attempts to view the TV dashboard for the {string} league") do |viewer, league|
  visit_tv_as(viewer, league)
end

When("a guest attempts to view the TV dashboard for the {string} league") do |league|
  visit "/signup"
  sign_out if page.has_button?("Sign out", wait: 0)
  visit tv_path_for(league)
end

Then("access is refused with {string}") do |message|
  expect(page).to have_current_path("/")
  expect(page).to have_css(".flash--alert", text: message)
end

Then("the guest is sent to sign in") do
  expect(page).to have_current_path("/login")
  expect(page).to have_css(".flash--alert", text: "you must be signed in")
end
