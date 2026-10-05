# A player's match history: every match they played, newest first, each
# with the result line ("Alice beats Bob 21-8") and the player's points
# after that match — the running balance from the stake fold
# (docs/DOMAIN.md). Shown ten matches per page: page one holds the newest.
module Statistics
  module MatchHistory
    Row = Data.define(:line, :points_after)
    Page = Data.define(:rows, :number, :pages)

    PER_PAGE = 10

    extend self

    # entries: StakeLedger::Entry values in match order (oldest first).
    # number is clamped into range, so any integer is safe to pass.
    def page(entries, player_id:, names:, number:)
      all = rows(entries, player_id:, names:)
      pages = [ (all.size.to_f / PER_PAGE).ceil, 1 ].max
      current = number.clamp(1, pages)
      Page.new(rows: all[(current - 1) * PER_PAGE, PER_PAGE], number: current, pages:)
    end

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
