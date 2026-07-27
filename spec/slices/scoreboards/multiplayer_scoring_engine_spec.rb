require "rails_helper"

RSpec.describe Scoreboards::MultiplayerScoringEngine do
  def engine(game_type: "Golf", stake_percentage: 10)
    described_class.new(stake_percentage:, game_type:)
  end

  describe "ranking direction" do
    it "ranks ascending for Golf (lowest score is 1st)" do
      points = { "alice" => 1000, "bob" => 1000, "carol" => 1000 }
      players = [{ id: "bob", score: 0 }, { id: "alice", score: 5 }, { id: "carol", score: 0 }]

      settled = engine(game_type: "Golf").settle(points, players)

      # Bob and Carol tied for 1st (position 0), Alice is 3rd (position 2)
      # Alice stakes floor(1000 * 0.625 * 10 / 100) = 62
      # Pot = 62; split between Bob and Carol equally: 31 each
      expect(settled).to eq({ "alice" => 938, "bob" => 1031, "carol" => 1031 })
    end

    it "ranks descending for Foosball (highest score is 1st)" do
      points = { "alice" => 1000, "bob" => 1000 }
      players = [{ id: "alice", score: 21 }, { id: "bob", score: 15 }]

      settled = engine(game_type: "Foosball").settle(points, players)

      # Alice 1st (0% stake), Bob 2nd (100% of 10% = 100)
      expect(settled).to eq({ "alice" => 1100, "bob" => 900 })
    end
  end

  describe "single player" do
    it "returns points unchanged for a single-player match" do
      points = { "alice" => 1000 }
      players = [{ id: "alice", score: 5 }]

      settled = engine.settle(points, players)
      expect(settled).to eq({ "alice" => 1000 })
    end
  end

  describe "two players" do
    it "stakes 100% for 2nd place" do
      points = { "alice" => 1000, "bob" => 1000 }
      players = [{ id: "alice", score: 10 }, { id: "bob", score: 5 }]

      settled = engine(game_type: "Foosball").settle(points, players)
      expect(settled).to eq({ "alice" => 1100, "bob" => 900 })
    end

    it "uses the stake percentage" do
      points = { "alice" => 1000, "bob" => 1000 }
      players = [{ id: "alice", score: 10 }, { id: "bob", score: 5 }]

      settled = engine(game_type: "Foosball", stake_percentage: 20).settle(points, players)
      expect(settled).to eq({ "alice" => 1200, "bob" => 800 })
    end
  end

  describe "three players" do
    it "uses ratios [0, 0.375, 0.625]" do
      # Alice 10 (1st), Bob 5 (2nd), Carol 0 (3rd)
      # Bob stakes 3.75% of 1000 = 37, Carol stakes 6.25% of 1000 = 62, pot = 99
      # Alice gets 99 -> 1099
      points = { "alice" => 1000, "bob" => 1000, "carol" => 1000 }
      players = [{ id: "alice", score: 10 }, { id: "bob", score: 5 }, { id: "carol", score: 0 }]

      settled = engine(game_type: "Foosball").settle(points, players)

      expect(settled["alice"]).to eq(1099)
      expect(settled["bob"]).to eq(963)
      expect(settled["carol"]).to eq(938)
    end

    it "handles ties (equal ratio for tied positions)" do
      # Carol 0 (1st/solo at pos 0), Alice 10 & Bob 10 (tied 2nd/3rd)
      # Alice & Bob: avg ratio = (0.375 + 0.625) / 2 = 0.5
      # Alice stakes 50, Bob stakes 50, pot = 100
      # Carol (sole winner) gets all 100 -> 1100
      points = { "alice" => 1000, "bob" => 1000, "carol" => 1000 }
      players = [{ id: "carol", score: 0 }, { id: "alice", score: 10 }, { id: "bob", score: 10 }]

      settled = engine(game_type: "Golf").settle(points, players)

      expect(settled["carol"]).to eq(1100)
      expect(settled["alice"]).to eq(950)
      expect(settled["bob"]).to eq(950)
    end

    it "uses descending ranking for Foosball" do
      points = { "alice" => 1000, "bob" => 1000, "carol" => 1000 }
      players = [{ id: "alice", score: 21 }, { id: "bob", score: 15 }, { id: "carol", score: 8 }]

      settled = engine(game_type: "Foosball").settle(points, players)

      # Alice 1st (0%), Bob 2nd (37), Carol 3rd (62), pot = 99
      expect(settled["alice"]).to eq(1099)
      expect(settled["bob"]).to eq(963)
      expect(settled["carol"]).to eq(938)
    end
  end

  describe "four players" do
    it "uses ratios [0, 0.25, 0.40, 0.35]" do
      # Descending for Foosball: 20(1st), 15(2nd), 10(3rd), 5(4th)
      # 2nd: 1000*0.25*10/100=25, 3rd: 1000*0.40*10/100=40, 4th: 1000*0.35*10/100=35, pot=100
      # 1st gets 100 -> 1100
      points = { "a" => 1000, "b" => 1000, "c" => 1000, "d" => 1000 }
      players = [{ id: "a", score: 20 }, { id: "b", score: 15 }, { id: "c", score: 10 }, { id: "d", score: 5 }]

      settled = engine(game_type: "Foosball").settle(points, players)

      expect(settled["a"]).to eq(1100)
      expect(settled["b"]).to eq(975)
      expect(settled["c"]).to eq(960)
      expect(settled["d"]).to eq(965)
    end
  end

  describe "zero-sum" do
    it "the total points never change" do
      points = { "a" => 1000, "b" => 1000, "c" => 1000, "d" => 1000, "e" => 1000 }
      players = [{ id: "a", score: 50 }, { id: "b", score: 40 }, { id: "c", score: 30 },
                 { id: "d", score: 20 }, { id: "e", score: 10 }]

      settled = engine(game_type: "Foosball").settle(points, players)
      expect(settled.values.sum).to eq(points.values.sum)
    end
  end

  describe "negative scores" do
    it "accepts negative scores and ranks correctly" do
      # Golf ascending: Bob -50 (1st/0% stake), Alice 10 (2nd/37), Carol 30 (3rd/62)
      # Pot = 37 + 62 = 99. Bob gets 99 -> 1099.
      points = { "bob" => 1000, "alice" => 1000, "carol" => 1000 }
      players = [{ id: "bob", score: -50 }, { id: "alice", score: 10 }, { id: "carol", score: 30 }]

      settled = engine(game_type: "Golf").settle(points, players)

      expect(settled["bob"]).to eq(1099)
      expect(settled["alice"]).to eq(963)
      expect(settled["carol"]).to eq(938)
    end
  end
end