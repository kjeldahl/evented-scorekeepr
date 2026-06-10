# Pure arithmetic for the zero-sum stake model (docs/DOMAIN.md): each loser
# stakes stake_percentage% of their current points rounded down (integer
# division); the pot — the sum of the stakes — is split among the winners
# with integer division, and the remainder is handed out one point at a time
# to the winners in the order they were listed on the match.
module Scoreboards
  class ScoringEngine
    def initialize(stake_percentage:)
      @stake_percentage = stake_percentage
    end

    # points: { player_id => current points } covering every winner and
    # loser. Returns the points after the match is settled.
    def settle(points, winners:, losers:)
      stakes = losers.to_h { |loser| [ loser, stake(points.fetch(loser)) ] }
      collected = points.merge(stakes) { |_loser, current, staked| current - staked }
      award(collected, winners:, pot: stakes.values.sum)
    end

    # The loser's stake, rounded down: (points * stake%) / 100.
    def stake(points)
      points * @stake_percentage / 100
    end

    private

    def award(points, winners:, pot:)
      share, remainder = pot.divmod(winners.size)
      winners.each_with_index.reduce(points) do |awarded, (winner, index)|
        bonus = index < remainder ? 1 : 0
        awarded.merge(winner => awarded.fetch(winner) + share + bonus)
      end
    end
  end
end
