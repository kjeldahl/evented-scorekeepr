# Pure integer arithmetic for the multiplayer zero-sum stake model
# (docs/DOMAIN.md): players are ranked by score (descending for Foosball/Table
# Tennis, ascending for Golf), positions determine stakes via internal
# distribution basis-points (scaled by the league's stake_percentage), and the
# pot is distributed to the winner(s) with integer division + remainder one-
# at-a-time.
#
# All arithmetic is integer only — no floats, no rounding drift, no loss or
# creation of points. The pot (sum of all stakes) equals the total deducted
# from losers. Winners receive exactly the pot. Zero-sum invariant preserved.
#
# A match with a single player is trivial: no stakes, no gains.
# Tied players share the average basis-points of their shared positions.
module Scoreboards
  class MultiplayerScoringEngine
    def initialize(stake_percentage:, game_type:)
      @stake_percentage = stake_percentage
      @game_type = game_type
    end

    # points: { player_id => current_points } covering every player.
    # players: [{ id:, score: }] — every player in the match.
    # => { player_id => points_after } for every player. A single player is
    # the sole winner of an empty pot, so their points come back unchanged.
    def settle(points, players)
      basis_points = compute_basis_points(rank(players), players.size)
      award(points, compute_stakes(basis_points, points), basis_points)
    end

    private

    def rank(players)
      direction = MultiplayerGameType.find(@game_type).fetch(:ranking)
      players
        .sort_by { |p| p.fetch(:score) }
        .then { |s| direction == :desc ? s.reverse : s }
        .map.with_index { |p, i| p.merge(position: i) }
    end

    # Compute basis-points (×10000) per player with competition ranking and tie
    # averaging. Returns { player_id => basis_point } in ranked order. Winners
    # (everyone tied with position 0) get basis_point 0.
    def compute_basis_points(ranked, player_count)
      ranked.to_h do |player|
        tied_group = ranked.select { |p| p.fetch(:score) == player.fetch(:score) }
        [ player.fetch(:id), tied_basis_point(tied_group, player_count) ]
      end
    end

    def tied_basis_point(tied_group, player_count)
      positions = tied_group.map { |p| p.fetch(:position) }
      return 0 if positions.include?(0) # this tie group includes 1st place: all are winners

      positions.sum { |position| MultiplayerDistribution.basis_point_for(player_count, position) } / positions.size
    end

    # stake = player_points * basis_points * stake_percentage / 1_000_000
    #   (= float: points * (bp / 10000.0) * stake / 100, purely integer).
    # Winners have basis_point 0, so they stake nothing.
    def compute_stakes(basis_points, points)
      basis_points.to_h { |id, bp| [ id, points.fetch(id) * bp * @stake_percentage / 1_000_000 ] }
    end

    # Winners (basis_point 0) split the pot in ranked order: the remainder of
    # the integer division goes one point at a time to the best-ranked winners.
    def award(points, stakes, basis_points)
      winners = basis_points.select { |_id, bp| bp.zero? }.keys
      collected = points.merge(stakes) { |_id, current, staked| current - staked }
      share, remainder = stakes.values.sum.divmod(winners.size)
      winners.each_with_index.reduce(collected) do |awarded, (winner, index)|
        bonus = index < remainder ? 1 : 0
        awarded.merge(winner => awarded.fetch(winner) + share + bonus)
      end
    end
  end
end
