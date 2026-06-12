# frozen_string_literal: true

# Player-statistics world helpers. The player page is reached by clicking
# the player's name on the scoreboard (that link IS the navigation spec);
# assertions read the rendered summary line, form line and the two tables.
#
# Public helper API:
#   open_player_page(viewer, player_name, league_name)  # via the scoreboard's player link
#   player_page_path(player_name, league_name)          # the direct URL (for rejection paths)
#   player_page_summary                                 # the rendered summary line text
#   player_page_form                                    # the rendered form tokens ("W W L")
#   expect_player_page_table(css, table)                # strict compare against a Gherkin table
#   match_history_pager                                 # the pager nav under the history table
module StatisticsWorld
  def open_player_page(viewer, player_name, league_name)
    visit_scoreboard_as(viewer, league_name)
    within("table.scoreboard") { click_link player_name }
  end

  def player_page_path(player_name, league_name)
    league = league_for(league_name)
    "/accounts/#{league.account_id}/leagues/#{league.id}/players/#{user_id_for(player_name)}"
  end

  def player_page_summary
    page.find(".player-summary").text
  end

  def player_page_form
    page.find(".player-form .form-results").text
  end

  def match_history_pager
    page.find("nav.pagination")
  end

  def player_page_table_rows(css)
    headers = page.all("#{css} thead th").map { |header| header.text.strip.downcase }
    page.all("#{css} tbody tr").map do |row|
      headers.zip(row.all("td").map { |cell| cell.text.strip }).to_h
    end
  end

  # Compares a rendered player-page table against the Gherkin table: same
  # number of rows, same order, and every cell under the table's headers exact.
  def expect_player_page_table(css, table)
    rendered = player_page_table_rows(css)
    expected = table.hashes
    expect(rendered.size).to eq(expected.size)
    expected.each_with_index do |expected_row, index|
      expect(rendered[index].slice(*expected_row.keys)).to eq(expected_row)
    end
  end
end

World(StatisticsWorld)
