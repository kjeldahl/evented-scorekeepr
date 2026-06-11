# frozen_string_literal: true

# Statistics slice steps. Player-page helpers (open_player_page,
# player_page_summary, expect_player_page_table, ...) live in
# features/support/statistics_world.rb. "Opens X's statistics page" always
# navigates by clicking the player's name on the scoreboard — that link is
# the feature's navigation spec; only the rejection path visits the URL
# directly (a non-member never sees the scoreboard link).

When("{string} opens {string}'s statistics page in {string}") do |viewer, player, league|
  open_player_page(viewer, player, league)
end

Then("the player page shows {int} points, rank {int} and {int} matches played") do |points, rank, played|
  expect(player_page_summary).to eq("#{points} points · rank #{rank} · #{played} matches played")
end

Then("the player page shows form {string}") do |form|
  expect(player_page_form).to eq(form)
end

Then("the head-to-head table shows:") do |table|
  expect_player_page_table("table.head-to-head", table)
end

Then("the match history shows:") do |table|
  expect_player_page_table("table.match-history", table)
end

Then("{string} cannot see {string}'s statistics page in {string}") do |viewer, player, league|
  sign_in(viewer) unless signed_in_as?(viewer)
  visit player_page_path(player, league)
  expect(page).to have_current_path("/")
  expect(page).to have_css(".flash--alert")
  expect(page).to have_no_css(".player-summary")
end
