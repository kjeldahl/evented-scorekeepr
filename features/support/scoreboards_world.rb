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
    expect_table_rows(scoreboard_rows, table)
  end

  def expect_table_rows(rendered, table)
    expected = table.hashes
    expect(rendered.size).to eq(expected.size)
    expected.each_with_index do |expected_row, index|
      expect(rendered[index].slice(*expected_row.keys)).to eq(expected_row)
    end
  end

  # --- TV dashboard helpers ---------------------------------------------
  #   visit_tv_as(viewer, league_name)      # signs the viewer in and opens the TV page
  #   tv_path_for(league_name)              # the TV page path
  #   tv_rows                               # rendered standings rows, keyed by header
  #   tv_recent_matches                     # the latest-matches lines, top to bottom
  #   tv_version_as(viewer, league_name)    # GETs the version endpoint, returns the integer

  def visit_tv_as(viewer, league_name)
    sign_in(viewer) unless signed_in_as?(viewer)
    visit tv_path_for(league_name)
  end

  def tv_path_for(league_name)
    league = league_for(league_name)
    "/accounts/#{league.account_id}/leagues/#{league.id}/tv"
  end

  def tv_rows
    headers = page.all(".tv-standings thead th").map { |header| header.text.strip.downcase }
    page.all(".tv-standings tbody tr").map do |row|
      headers.zip(row.all("td").map { |cell| cell.text.strip }).to_h
    end
  end

  def tv_recent_matches
    page.all(".tv-recent li").map { |item| item.text.strip }
  end

  def tv_version_as(viewer, league_name)
    sign_in(viewer) unless signed_in_as?(viewer)
    visit "#{tv_path_for(league_name)}/version"
    JSON.parse(page.body).fetch("version")
  end

  # --- TV live updates ----------------------------------------------------
  #   tv_stream_broadcasts(league_name)  # broadcasts recorded by the test
  #                                      # cable adapter on the league's
  #                                      # "events:league:{id}" stream
  def tv_stream_broadcasts(league_name)
    ActionCable.server.pubsub.broadcasts("events:league:#{league_for(league_name).id}")
  end
end

World(ScoreboardsWorld)
