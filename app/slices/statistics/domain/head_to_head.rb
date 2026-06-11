# A player's head-to-head record: one row per opponent they have faced. An
# opponent is any player on the other side of a match, in 1v1 and 2v2 alike
# — a teammate is never an opponent. Rows are ordered by most played, then
# by opponent name (docs/DOMAIN.md).
module Statistics
  module HeadToHead
    Row = Data.define(:opponent, :played, :won, :lost)

    extend self

    # matches: the league's matches oldest first.
    # names: { player_id => display name } (ids fall back to themselves).
    def rows(matches, player_id:, names:)
      tallies(matches, player_id)
        .map { |opponent, tally| Row.new(opponent: names.fetch(opponent, opponent), **tally) }
        .sort_by { |row| [ -row.played, row.opponent ] }
    end

    private

    def tallies(matches, player_id)
      matches.select { |match| match.involves?(player_id) }
             .reduce({}) { |folded, match| record(folded, match, player_id) }
    end

    def record(tallies, match, player_id)
      won = match.won_by?(player_id)
      match.opponents_of(player_id).reduce(tallies) do |folded, opponent|
        folded.merge(opponent => advance(folded[opponent], won))
      end
    end

    def advance(tally, won)
      tally ||= { played: 0, won: 0, lost: 0 }
      counted = won ? tally.merge(won: tally.fetch(:won) + 1) : tally.merge(lost: tally.fetch(:lost) + 1)
      counted.merge(played: tally.fetch(:played) + 1)
    end
  end
end
