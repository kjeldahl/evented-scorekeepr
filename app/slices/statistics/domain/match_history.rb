# A player's match history: every match they played, newest first, each
# with the result line ("Alice beats Bob 21-8") and the player's points
# after that match — the running balance from the stake fold
# (docs/DOMAIN.md).
module Statistics
  module MatchHistory
    Row = Data.define(:line, :points_after)

    extend self

    # entries: StakeLedger::Entry values in match order (oldest first).
    def rows(entries, player_id:, names:)
      entries.select { |entry| entry.match.involves?(player_id) }
             .reverse
             .map { |entry| row(entry, player_id, names) }
    end

    private

    def row(entry, player_id, names)
      Row.new(line: MatchLine.format(entry.match, names), points_after: entry.points.fetch(player_id))
    end
  end
end
