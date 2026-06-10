# frozen_string_literal: true

# Scoreboard-related world helpers. The scoreboard page is the league page;
# assertions about points and standings read the rendered standings table.
#
# Public helper API:
#   visit_scoreboard_as(viewer, league_name)   # signs the viewer in and opens the league page
#   visit_scoreboard_as_member(league_name)    # opens it as the account owner (always a member)
#   scoreboard_rows                            # rendered rows as [{ "rank" => "1", "player" => "Alice", ... }]
#   scoreboard_players                         # the player column, top to bottom
#   scoreboard_cell(player, column)            # one player's rendered cell (raises when not listed)
#   expect_scoreboard(table)                   # strict compare against a Gherkin table (columns by header)
module ScoreboardsWorld
  def visit_scoreboard_as(viewer, league_name)
    sign_in(viewer) unless signed_in_as?(viewer)
    league = league_for(league_name)
    visit "/accounts/#{league.account_id}/leagues/#{league.id}/scoreboard"
  end

  def visit_scoreboard_as_member(league_name)
    visit_scoreboard_as(owner_name_for(league_for(league_name).account_id), league_name)
  end

  def scoreboard_rows
    headers = page.all("table.scoreboard thead th").map { |header| header.text.strip.downcase }
    page.all("table.scoreboard tbody tr").map do |row|
      headers.zip(row.all("td").map { |cell| cell.text.strip }).to_h
    end
  end

  def scoreboard_players
    scoreboard_rows.map { |row| row.fetch("player") }
  end

  def scoreboard_cell(player, column)
    row = scoreboard_rows.find { |candidate| candidate["player"] == player } or
      raise "#{player.inspect} is not on the scoreboard (players: #{scoreboard_players.inspect})"
    row.fetch(column)
  end

  # Compares the rendered standings against the Gherkin table: same number
  # of rows, same order, and every cell under the table's headers exact.
  def expect_scoreboard(table)
    rendered = scoreboard_rows
    expected = table.hashes
    expect(rendered.size).to eq(expected.size)
    expected.each_with_index do |expected_row, index|
      expect(rendered[index].slice(*expected_row.keys)).to eq(expected_row)
    end
  end
end

World(ScoreboardsWorld)
