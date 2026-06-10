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

# The scoreboard page is the league page (docs/ARCHITECTURE.md), so both
# refusal phrases land there: a non-member is bounced to the dashboard with
# an alert and never sees the league's name or its standings.
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
