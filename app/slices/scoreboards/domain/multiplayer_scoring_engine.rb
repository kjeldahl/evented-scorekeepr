# Pure arithmetic for the multiplayer zero-sum stake model (docs/DOMAIN.md):
# players are ranked by score (descending for Foosball/Table Tennis,
# ascending for Golf), positions determine stakes via internal distribution
# ratios (scaled by the league's stake_percentage), and the pot is distributed
# to the winner(s) with integer division + remainder one-at-a-time.
#
# A match with a single player is trivial: no stakes, no gains.
# Tied players share the average ratio of their shared positions.
module Scoreboards
  class MultiplayerScoringEngine
    def initialize(stake_percentage:, game_type:)
      @stake_percentage = stake_percentage
      @game_type = game_type
    end

    # points: { player_id => current points } covering every player.
    # players: [{ id:, score: }] — every player in the match.
    # => { player_id => points_after } for every player.
    def settle(points, players)
      return points if players.one? # single player: no stakes, no gains

      ranked = rank(players)
      ratios = compute_ratios(ranked, players.size)
      stakes = compute_stakes(ranked, ratios, points)
      pot = stakes.values.sum
      award(points, stakes, pot, ranked, ratios)
    end

    private

    def rank(players)
      config = Matches::GameType.find(@game_type)
      direction = config[:ranking]
      players
        .sort_by { |p| p[:score] }
        .then { |s| direction == :desc ? s.reverse : s }
        .map.with_index { |p, i| p.merge(position: i) }
    end

    # Compute position ratios with competition ranking and tie averaging.
    # Returns { player_id => ratio }. Winners at position 0 get ratio 0.0.
    def compute_ratios(ranked, player_count)
      # Assign each player a distinct sequential position (0-indexed), then
      # compute average ratios for tied players. Tied players share the same
      # score and their positions form a contiguous block. If any player in
      # the tie group is at position 0, all are winners (ratio 0.0).
      positions = {}
      ranked.each_with_index { |p, i| positions[p[:id]] = i }

      positions.each_with_object({}) do |(id, _), acc|
        score = ranked.find { |p| p[:id] == id }[:score]
        tied_group = ranked.select { |p| p[:score] == score }

        if tied_group.any? { |p| positions[p[:id]].zero? }
          # This tie group includes 1st place: all are winners
          acc[id] = 0.0
        else
          avg_ratio = tied_group.sum { |p| Matches::Distribution.ratio_for(player_count, positions.fetch(p[:id])) } / tied_group.size.to_f
          acc[id] = avg_ratio
        end
      end
    end

    def compute_stakes(ranked, ratios, points)
      ranked.filter_map do |player|
        id = player[:id]
        ratio = ratios.fetch(id)
        next nil if ratio.zero? # winners pay nothing

        stake = Integer(points.fetch(id) * ratio * @stake_percentage / 100)
        [ id, stake ]
      end.to_h
    end

    def award(points, stakes, pot, ranked, ratios)
      # Winners are those with ratio 0.0 (any tied group that includes position 0)
      winners = ratios.each_with_object([]) { |(id, ratio), acc| acc << id if ratio.zero? }
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