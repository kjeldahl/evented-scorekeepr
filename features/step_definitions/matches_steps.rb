# frozen_string_literal: true

# Matches slice steps. Match helpers (register_match, match_events,
# recent_match_lines, ...) live in features/support/matches_world.rb so the
# scoring, scoreboards and multi-tenancy features can reuse the shared
# phrases ("X registers a match in L where ...", "the recent matches show").

When("{string} registers a match in {string} where {string} beats {string} {int}-{int}") \
do |registrar, league, winner, loser, winner_score, loser_score|
  register_match!(registrar, league:, home: [ winner ], away: [ loser ],
                             home_score: winner_score, away_score: loser_score)
end

Given("{string} registers {int} matches in {string} where {string} beats {string} {int}-{int}") \
do |registrar, count, league, winner, loser, winner_score, loser_score|
  count.times do
    register_match!(registrar, league:, home: [ winner ], away: [ loser ],
                               home_score: winner_score, away_score: loser_score)
  end
end

When("{string} registers a match in {string} where {string} and {string} beat {string} and {string} {int}-{int}") \
do |registrar, league, winner_1, winner_2, loser_1, loser_2, winner_score, loser_score|
  register_match!(registrar, league:, home: [ winner_1, winner_2 ], away: [ loser_1, loser_2 ],
                             home_score: winner_score, away_score: loser_score)
end

When("{string} attempts to register a match in {string} where {string} beats {string} {int}-{int}") \
do |registrar, league, winner, loser, winner_score, loser_score|
  register_match(registrar, league:, home: [ winner ], away: [ loser ],
                            home_score: winner_score, away_score: loser_score, via_ui: false)
end

When("{string} attempts to register a match in {string} " \
     "where {string} and {string} beat {string} and {string} {int}-{int}") \
do |registrar, league, winner_1, winner_2, loser_1, loser_2, winner_score, loser_score|
  register_match(registrar, league:, home: [ winner_1, winner_2 ], away: [ loser_1, loser_2 ],
                            home_score: winner_score, away_score: loser_score, via_ui: false)
end

When("{string} attempts to register a match in {string} " \
     "where {string} plays {string} with home score {string} and away score {string}") \
do |registrar, league, home_player, away_player, home_score, away_score|
  register_match(registrar, league:, home: [ home_player ], away: [ away_player ],
                            home_score:, away_score:, via_ui: false)
end

Then("the match is accepted") do
  expect(last_match_registered?).to be(true)
end

Then("the match is rejected because {string}") do |reason|
  expect(page).to have_css(".flash--alert", text: reason)
  expect(matches_registered_during_last_attempt).to eq(0)
end

Then("the recent matches in {string} show:") do |league, table|
  expect(recent_match_lines(league)).to eq(table.hashes.map { |row| row.fetch("match") })
end

# --- Editing matches (features/matches/edit_match.feature) -----------------
# Edit helpers (edit_match!, attempt_edit, edit_match_path, ...) live in
# features/support/matches_world.rb. The happy path drives the real edit
# form; rejection paths PATCH raw scores (a non-player never sees the form).

When("{string} edits the match where {string} beats {string} {int}-{int} in {string} " \
     "so that {string} beats {string} {int}-{int}") \
do |editor, winner, loser, winner_score, loser_score, league, new_winner, new_loser, new_winner_score, new_loser_score|
  edit_match!(editor, league:, winners: [ winner ], losers: [ loser ],
                      winner_score:, loser_score:,
                      new_winners: [ new_winner ], new_losers: [ new_loser ],
                      new_winner_score:, new_loser_score:)
end

When("{string} edits the match where {string} and {string} beat {string} and {string} {int}-{int} in {string} " \
     "so that {string} and {string} beat {string} and {string} {int}-{int}") \
do |editor, w1, w2, l1, l2, winner_score, loser_score, league, nw1, nw2, nl1, nl2, new_winner_score, new_loser_score|
  edit_match!(editor, league:, winners: [ w1, w2 ], losers: [ l1, l2 ],
                      winner_score:, loser_score:,
                      new_winners: [ nw1, nw2 ], new_losers: [ nl1, nl2 ],
                      new_winner_score:, new_loser_score:)
end

When("{string} attempts to edit the match where {string} beats {string} {int}-{int} in {string} " \
     "with home score {string} and away score {string}") \
do |editor, winner, loser, winner_score, loser_score, league, home_score, away_score|
  attempt_edit(editor, league:, winners: [ winner ], losers: [ loser ],
                       winner_score:, loser_score:, home_score:, away_score:)
end

Then("{string} sees an edit link for the match where {string} beats {string} {int}-{int} in {string}") \
do |viewer, winner, loser, winner_score, loser_score, league|
  event = find_registered_match(league, winners: [ winner ], losers: [ loser ], winner_score:, loser_score:)
  visit_scoreboard_as(viewer, league)
  expect(page).to have_link("Edit", href: edit_match_path(league, event.data.fetch(:match_id)))
end

Then("{string} sees no edit link for the match where {string} beats {string} {int}-{int} in {string}") \
do |viewer, winner, loser, winner_score, loser_score, league|
  event = find_registered_match(league, winners: [ winner ], losers: [ loser ], winner_score:, loser_score:)
  visit_scoreboard_as(viewer, league)
  expect(page).to have_no_link("Edit", href: edit_match_path(league, event.data.fetch(:match_id)))
end

Then("the edit is rejected because {string}") do |reason|
  expect(page).to have_css(".flash--alert", text: reason)
  expect(corrections_after_last_edit_attempt).to eq(0)
end
