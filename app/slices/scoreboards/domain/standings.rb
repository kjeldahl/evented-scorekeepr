# Pure fold of a league's matches (oldest first) into ranked standings rows:
# a player enters with the league's starting points the first time they
# appear in a match, the ScoringEngine settles each match's stakes, and the
# fold tracks per-player statistics. Ranking is by points descending; tied
# players are ordered by name with sequential ranks (docs/DOMAIN.md).
module Scoreboards
  class Standings
    Row = Data.define(:rank, :player_id, :name, :points, :played, :wins, :losses,
                      :win_percentage, :points_for, :points_against, :streak)

    Streak = Data.define(:kind, :length) do
      def self.none = new(kind: nil, length: 0)
      def advance(result) = kind == result ? with(length: length + 1) : Streak.new(kind: result, length: 1)
      def to_s = "#{kind}#{length}"
    end

    Stats = Data.define(:points, :played, :wins, :losses, :points_for, :points_against, :streak) do
      def self.seed(points)
        new(points:, played: 0, wins: 0, losses: 0, points_for: 0, points_against: 0, streak: Streak.none)
      end

      def won(scored, conceded) = played_match(scored, conceded, wins: wins + 1, streak: streak.advance("W"))
      def lost(scored, conceded) = played_match(scored, conceded, losses: losses + 1, streak: streak.advance("L"))
      def win_percentage = (100.0 * wins / played).round

      private

      def played_match(scored, conceded, **outcome)
        with(played: played + 1, points_for: points_for + scored,
             points_against: points_against + conceded, **outcome)
      end
    end

    def initialize(starting_points:, stake_percentage:)
      @starting_points = starting_points
      @engine = ScoringEngine.new(stake_percentage:)
    end

    # matches: Scoreboards::Match values in registration order (oldest
    # first). names: { player_id => display name }, used for tie-breaking
    # and the rendered rows. Returns ranked rows, best first.
    def table(matches, names:)
      stats = matches.reduce({}) { |folded, match| apply(folded, match) }
      rank(stats, names)
    end

    private

    def apply(stats, match)
      record_results(settle_points(seed(stats, match.players), match), match)
    end

    def seed(stats, players)
      players.reduce(stats) { |seeded, player| seeded.key?(player) ? seeded : seeded.merge(player => Stats.seed(@starting_points)) }
    end

    def settle_points(stats, match)
      settled = @engine.settle(stats.transform_values(&:points), winners: match.winners, losers: match.losers)
      stats.to_h { |player, player_stats| [ player, player_stats.with(points: settled.fetch(player)) ] }
    end

    def record_results(stats, match)
      won = match.winners.reduce(stats) do |updated, winner|
        updated.merge(winner => updated.fetch(winner).won(match.winner_score, match.loser_score))
      end
      match.losers.reduce(won) do |updated, loser|
        updated.merge(loser => updated.fetch(loser).lost(match.loser_score, match.winner_score))
      end
    end

    def rank(stats, names)
      sorted = stats.sort_by { |player, player_stats| [ -player_stats.points, names.fetch(player, player) ] }
      sorted.each_with_index.map { |(player, player_stats), index| row(index + 1, player, player_stats, names) }
    end

    def row(rank, player, stats, names)
      Row.new(rank:, player_id: player, name: names.fetch(player, player),
              points: stats.points, played: stats.played, wins: stats.wins, losses: stats.losses,
              win_percentage: stats.win_percentage, points_for: stats.points_for,
              points_against: stats.points_against, streak: stats.streak.to_s)
    end
  end
end
