# Pure fold of a league's matches (oldest first) into ranked standings rows:
# a player enters with the league's starting points the first time they
# appear in a match, the ScoringEngine settles each match's stakes, and the
# fold tracks per-player statistics. Ranking is by points descending; tied
# players are ordered by name with sequential ranks (docs/DOMAIN.md).
# Supports both head-to-head matches and multiplayer matches (game_type
# determines which scoring engine is used).
module Scoreboards
  class Standings
    Row = Data.define(:rank, :player_id, :name, :points, :played, :wins, :losses,
                      :win_percentage, :points_for, :points_against, :streak,
                      :streak_kind, :streak_length)

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
      def win_percentage = played.zero? ? 0 : (100.0 * wins / played).round

      private

      def played_match(scored, conceded, **outcome)
        with(played: played + 1, points_for: points_for + scored,
             points_against: points_against + conceded, **outcome)
      end
    end

    def initialize(starting_points:, stake_percentage:, game_type:, match_type:)
      @starting_points = starting_points
      @stake_percentage = stake_percentage
      @game_type = game_type
      @match_type = match_type
    end

    # matches: Scoreboards::Match or Scoreboards::MultiplayerMatch values in
    # registration order (oldest first). names: { player_id => display name }.
    # Returns ranked rows, best first.
    def table(matches, names:)
      stats = matches.reduce({}) { |folded, match| apply(folded, match) }
      rank(stats.reject { |_id, s| s.played.zero? }, names)
    end

    private

    def apply(stats, match)
      case match
      when Match then apply_match(stats, match)
      when MultiplayerMatch then apply_multi(stats, match)
      end
    end

    def apply_match(stats, match)
      record_results(settle_points(seed(stats, match.players), match), match)
    end

    def apply_multi(stats, match)
      return seed(stats, match.players) if match.deleted?

      record_multi_results(settle_multi_points(seed(stats, match.players), match), match)
    end

    def seed(stats, players)
      players.reduce(stats) { |seeded, player| seeded.key?(player) ? seeded : seeded.merge(player => Stats.seed(@starting_points)) }
    end

    def settle_points(stats, match)
      with_points(stats, engine.settle(stats.transform_values(&:points),
                                       winners: match.winners, losers: match.losers))
    end

    def settle_multi_points(stats, match)
      entrants = match.players.map { |id| { id:, score: score_of(match, id) } }
      with_points(stats, engine.settle(stats.transform_values(&:points), entrants))
    end

    # The settled points folded back onto each player's statistics.
    def with_points(stats, settled)
      stats.to_h { |player, player_stats| [ player, player_stats.with(points: settled.fetch(player)) ] }
    end

    # Every player of a multiplayer match has a score; a missing one is a
    # corrupt registration, not a zero.
    def score_of(match, player_id)
      match.player_scores.fetch(player_id.to_sym)
    end

    def record_results(stats, match)
      won = match.winners.reduce(stats) do |updated, winner|
        updated.merge(winner => updated.fetch(winner).won(match.winner_score, match.loser_score))
      end
      match.losers.reduce(won) do |updated, loser|
        updated.merge(loser => updated.fetch(loser).lost(match.loser_score, match.winner_score))
      end
    end

    # Only this match's players get a result - the fold's stats also carry
    # players from earlier matches, and they did not play in this one.
    def record_multi_results(stats, match)
      best_score = MultiplayerGameType.best_score(@game_type, match.player_ids.map { |id| score_of(match, id) })
      match.player_ids.reduce(stats) do |updated, player_id|
        updated.merge(player_id => multi_result(updated.fetch(player_id), score_of(match, player_id), best_score))
      end
    end

    # Everyone who tied the best score won the game; the rest lost it.
    def multi_result(player_stats, game_score, best_score)
      return player_stats.won(game_score, 0) if game_score == best_score

      player_stats.lost(0, game_score)
    end

    def rank(stats, names)
      sorted = stats.sort_by { |player, player_stats| [ -player_stats.points, names.fetch(player, player) ] }
      sorted.each_with_index.map { |(player, player_stats), index| row(index + 1, player, player_stats, names) }
    end

    def row(rank, player, stats, names)
      Row.new(rank:, player_id: player, name: names.fetch(player, player),
              points: stats.points, played: stats.played, wins: stats.wins, losses: stats.losses,
              win_percentage: stats.win_percentage, points_for: stats.points_for,
              points_against: stats.points_against, streak: stats.streak.to_s,
              streak_kind: stats.streak.kind, streak_length: stats.streak.length)
    end

    def engine
      @engine ||= case @match_type
      when "multiplayer"
                    MultiplayerScoringEngine.new(stake_percentage: @stake_percentage, game_type: @game_type)
      else
                    ScoringEngine.new(stake_percentage: @stake_percentage)
      end
    end
  end
end
