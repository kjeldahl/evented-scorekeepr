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
    # => { player_id => points_after } for every player.
    def settle(points, players)
      return points if players.one? # single player: no stakes, no gains

      ranked = rank(players)
      basis_points = compute_basis_points(ranked, players.size)
      stakes = compute_stakes(ranked, basis_points, points)
      pot = stakes.values.sum
      award(points, stakes, pot, ranked, basis_points)
    end

    private

    def rank(players)
      config = Scoreboards::MultiplayerGameType.find(@game_type)
      direction = config[:ranking]
      players
        .sort_by { |p| p[:score] }
        .then { |s| direction == :desc ? s.reverse : s }
        .map.with_index { |p, i| p.merge(position: i) }
    end

    # Compute basis-points (×10000) per player with competition ranking and tie
    # averaging.  Returns { player_id => basis_point }. Winners at position 0
    # get basis_point 0.
    def compute_basis_points(ranked, player_count)
      # Assign each player a distinct sequential position (0-indexed).
      positions = {}
      ranked.each_with_index { |p, i| positions[p[:id]] = i }

      positions.each_with_object({}) do |(id, _), acc|
        score = ranked.find { |p| p[:id] == id }[:score]
        tied_group = ranked.select { |p| p[:score] == score }

        if tied_group.any? { |p| positions[p[:id]].zero? }
          # This tie group includes 1st place: all are winners
          acc[id] = 0
        else
          avg_bp = tied_group.sum { |p| Scoreboards::MultiplayerDistribution.basis_point_for(player_count, positions.fetch(p[:id])) } / tied_group.size
          acc[id] = avg_bp
        end
      end
    end

    # stake = player_points * basis_points * stake_percentage / 1_000_000
    #   (= float: points * (bp / 10000.0) * stake / 100, purely integer)
    def compute_stakes(ranked, basis_points, points)
      ranked.filter_map do |player|
        id = player[:id]
        bp = basis_points.fetch(id)
        next nil if bp.zero? # winners pay nothing

        stake = points.fetch(id) * bp * @stake_percentage / 1_000_000
        [ id, stake ]
      end.to_h
    end

    def award(points, stakes, pot, ranked, basis_points)
      # Winners are those with basis_point 0
      winners = basis_points.each_with_object([]) { |(id, bp), acc| acc << id if bp.zero? }
      # Sort by ranked order for remainder distribution
      winners.sort_by! { |id| ranked.index { |p| p[:id] == id } }

      collected = points.transform_values(&:to_i)
                       .merge(stakes.transform_values(&:to_i)) { |_id, current, staked| current - staked }
      share, remainder = pot.divmod(winners.size)
      winners.each_with_index.reduce(collected) do |awarded, (winner, index)|
        bonus = index < remainder ? 1 : 0
        awarded.merge(winner => awarded.fetch(winner) + share + bonus)
      end
    end
  end
end
