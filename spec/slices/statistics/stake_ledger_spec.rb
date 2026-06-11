require "rails_helper"

RSpec.describe Statistics::StakeLedger do
  subject(:ledger) { described_class.new(starting_points: 1000, stake_percentage: 10) }

  def match(home, away, home_score, away_score)
    Statistics::Match.new(home_player_ids: home, away_player_ids: away, home_score:, away_score:)
  end

  describe "#entries" do
    it "is empty for no matches" do
      expect(ledger.entries([])).to eq([])
    end

    it "seeds both players with the starting points and settles the first match" do
      entries = ledger.entries([ match([ "a" ], [ "b" ], 21, 8) ])
      expect(entries.sole.points).to eq({ "a" => 1100, "b" => 900 })
    end

    it "carries the match onto its entry, in match order" do
      matches = [ match([ "a" ], [ "b" ], 21, 8), match([ "b" ], [ "a" ], 21, 19) ]
      expect(ledger.entries(matches).map(&:match)).to eq(matches)
    end

    it "records the running balance after each match, staking current points" do
      # Match 2: Alice stakes 10% of 1100 = 110, not 100 of her seed.
      entries = ledger.entries([ match([ "a" ], [ "b" ], 21, 8), match([ "b" ], [ "a" ], 21, 19) ])
      expect(entries.map(&:points)).to eq([ { "a" => 1100, "b" => 900 },
                                            { "a" => 990, "b" => 1010 } ])
    end

    it "seeds a player at the starting points when they first appear mid-league" do
      entries = ledger.entries([ match([ "a" ], [ "b" ], 21, 8), match([ "b" ], [ "c" ], 21, 15) ])
      expect(entries.last.points).to eq({ "a" => 1100, "b" => 1000, "c" => 900 })
    end

    it "keeps earlier entries frozen while later matches settle" do
      entries = ledger.entries([ match([ "a" ], [ "b" ], 21, 8), match([ "b" ], [ "a" ], 21, 19) ])
      expect(entries.first.points).to eq({ "a" => 1100, "b" => 900 })
    end

    it "splits a 2v2 pot and hands an odd remainder to the first-listed winner" do
      # Bob stakes 101 (of 1010), Dave stakes 100; pot 201 -> 100 each, +1 to Alice.
      entries = ledger.entries([ match([ "a" ], [ "b" ], 21, 8),
                                 match([ "b" ], [ "a" ], 21, 19),
                                 match(%w[a c], %w[b d], 10, 4) ])
      expect(entries.last.points).to eq({ "a" => 1091, "c" => 1100, "b" => 909, "d" => 900 })
    end

    it "follows the winning side's listed order for the remainder when the away side wins" do
      entries = ledger.entries([ match([ "a" ], [ "b" ], 21, 8),
                                 match([ "b" ], [ "a" ], 21, 19),
                                 match(%w[b d], %w[c a], 4, 10) ])
      expect(entries.last.points["c"]).to eq(1101)
      expect(entries.last.points["a"]).to eq(1090)
    end

    it "uses the configured starting points" do
      entries = described_class.new(starting_points: 1015, stake_percentage: 10)
                               .entries([ match([ "a" ], [ "b" ], 21, 8) ])
      expect(entries.sole.points).to eq({ "a" => 1116, "b" => 914 })
    end

    it "uses the configured stake percentage" do
      entries = described_class.new(starting_points: 1000, stake_percentage: 20)
                               .entries([ match([ "a" ], [ "b" ], 21, 8) ])
      expect(entries.sole.points).to eq({ "a" => 1200, "b" => 800 })
    end
  end

  describe "#final_points" do
    it "is empty for no matches" do
      expect(ledger.final_points([])).to eq({})
    end

    it "is the balance after the last match" do
      finals = ledger.final_points([ match([ "a" ], [ "b" ], 21, 8), match([ "b" ], [ "a" ], 21, 19) ])
      expect(finals).to eq({ "a" => 990, "b" => 1010 })
    end
  end
end
