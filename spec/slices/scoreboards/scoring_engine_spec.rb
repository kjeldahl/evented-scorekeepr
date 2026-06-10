require "rails_helper"

RSpec.describe Scoreboards::ScoringEngine do
  subject(:engine) { described_class.new(stake_percentage: 10) }

  describe "#stake" do
    it "takes the stake percentage of the points" do
      expect(engine.stake(1000)).to eq(100)
    end

    it "rounds down (integer division)" do
      expect(engine.stake(1015)).to eq(101)
    end

    it "rounds 999 down to 99, never up" do
      expect(engine.stake(999)).to eq(99)
    end

    it "is zero when the points are too small to stake" do
      expect(engine.stake(9)).to eq(0)
    end

    it "is zero for a player with zero points" do
      expect(engine.stake(0)).to eq(0)
    end

    it "uses the configured percentage" do
      expect(described_class.new(stake_percentage: 20).stake(1000)).to eq(200)
    end

    it "floors with a custom percentage too" do
      expect(described_class.new(stake_percentage: 3).stake(1010)).to eq(30)
    end
  end

  describe "#settle" do
    it "moves the loser's stake to the winner in a 1v1" do
      settled = engine.settle({ "alice" => 1000, "bob" => 1000 }, winners: [ "alice" ], losers: [ "bob" ])
      expect(settled).to eq({ "alice" => 1100, "bob" => 900 })
    end

    it "stakes the loser's current points, not their starting points" do
      settled = engine.settle({ "alice" => 1100, "bob" => 900 }, winners: [ "bob" ], losers: [ "alice" ])
      expect(settled).to eq({ "alice" => 990, "bob" => 1010 })
    end

    it "leaves players outside the match untouched" do
      settled = engine.settle({ "alice" => 1000, "bob" => 1000, "carol" => 1234 },
                              winners: [ "alice" ], losers: [ "bob" ])
      expect(settled["carol"]).to eq(1234)
    end

    it "splits an even 2v2 pot equally between the winners" do
      points = { "a" => 1000, "c" => 1000, "b" => 1000, "d" => 1000 }
      settled = engine.settle(points, winners: %w[a c], losers: %w[b d])
      expect(settled).to eq({ "a" => 1100, "c" => 1100, "b" => 900, "d" => 900 })
    end

    it "takes each loser's stake from their own current points" do
      points = { "d" => 1000, "e" => 1000, "b" => 1010, "c" => 1000 }
      settled = engine.settle(points, winners: %w[d e], losers: %w[b c])
      expect(settled["b"]).to eq(909)
      expect(settled["c"]).to eq(900)
    end

    it "hands an odd pot's remainder to the first-listed winner" do
      points = { "d" => 1000, "e" => 1000, "b" => 1010, "c" => 1000 }
      settled = engine.settle(points, winners: %w[d e], losers: %w[b c])
      expect(settled["d"]).to eq(1101)
      expect(settled["e"]).to eq(1100)
    end

    it "follows the winner listing order for the remainder, not the ids" do
      points = { "d" => 1000, "e" => 1000, "b" => 1010, "c" => 1000 }
      settled = engine.settle(points, winners: %w[e d], losers: %w[b c])
      expect(settled["e"]).to eq(1101)
      expect(settled["d"]).to eq(1100)
    end

    it "gives a single winner the whole pot from two losers" do
      points = { "a" => 1000, "b" => 1015, "c" => 1000 }
      settled = engine.settle(points, winners: [ "a" ], losers: %w[b c])
      expect(settled).to eq({ "a" => 1201, "b" => 914, "c" => 900 })
    end

    it "is zero-sum: the total points never change" do
      points = { "d" => 1000, "e" => 1000, "b" => 1010, "c" => 1003 }
      settled = engine.settle(points, winners: %w[d e], losers: %w[b c])
      expect(settled.values.sum).to eq(points.values.sum)
    end

    it "never drives a loser negative, even at high stakes" do
      settled = described_class.new(stake_percentage: 99).settle(
        { "a" => 1000, "b" => 1 }, winners: [ "a" ], losers: [ "b" ]
      )
      expect(settled["b"]).to eq(1)
      expect(settled["a"]).to eq(1000)
    end
  end
end
