# Selects the TV dashboard's spotlight rows from the ranked standings
# (Scoreboards::Standings::Row values, best rank first): the leader is the
# top row; the hot streak is the row with the longest current winning
# streak of at least 2 wins, ties going to the row ranked higher. Both are
# nil when no row qualifies (docs/DOMAIN.md § TV dashboard).
module Scoreboards
  module TvSpotlights
    extend self

    def leader(rows)
      rows.first
    end

    # max_by keeps the first row carrying the longest streak, so ties break
    # towards the row earlier in standings order.
    def hot_streak(rows)
      rows.select { |row| hot?(row) }.max_by(&:streak_length)
    end

    private

    def hot?(row)
      row.streak_kind == "W" && row.streak_length >= 2
    end
  end
end
