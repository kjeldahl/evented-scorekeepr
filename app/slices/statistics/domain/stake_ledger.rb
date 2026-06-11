# The stake fold behind the player page: replays a league's matches (oldest
# first) through the ScoringEngine and records every player's points balance
# after each match. A player enters with the league's starting points the
# first time they appear in a match (docs/DOMAIN.md).
module Statistics
  class StakeLedger
    # One ledger entry per match: the match and every seeded player's
    # balance immediately after that match was settled.
    Entry = Data.define(:match, :points)

    def initialize(starting_points:, stake_percentage:)
      @starting_points = starting_points
      @engine = ScoringEngine.new(stake_percentage:)
    end

    # matches: Statistics::Match values in registration order (oldest
    # first). Returns one Entry per match, in the same order.
    def entries(matches)
      balances = {}
      matches.map do |match|
        balances = @engine.settle(seed(balances, match.players), winners: match.winners, losers: match.losers)
        Entry.new(match:, points: balances)
      end
    end

    # The current balances after all matches: { player_id => points }.
    def final_points(matches)
      entries(matches).last&.points || {}
    end

    private

    def seed(balances, players)
      players.reduce(balances) do |seeded, player|
        seeded.key?(player) ? seeded : seeded.merge(player => @starting_points)
      end
    end
  end
end
