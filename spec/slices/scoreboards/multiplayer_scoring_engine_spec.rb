require "rails_helper"

RSpec.describe Scoreboards::MultiplayerScoringEngine do
  def engine(game_type: "Golf", stake_percentage: 10)
    described_class.new(stake_percentage:, game_type:)
  end

  describe "#rank" do
    it "ranks descending for Foosball (highest score first)" do
      players = [ { id: "bob", score: 5 }, { id: "alice", score: 10 }, { id: "carol", score: 3 } ]
      ranked = engine(game_type: "Foosball").send(:rank, players)
      expect(ranked.map { |p| p[:id] }).to eq(%w[alice bob carol])
      expect(ranked.map { |p| p[:position] }).to eq([ 0, 1, 2 ])
    end

    it "ranks ascending for Golf (lowest score first)" do
      players = [ { id: "alice", score: 10 }, { id: "bob", score: 5 }, { id: "carol", score: 3 } ]
      ranked = engine(game_type: "Golf").send(:rank, players)
      expect(ranked.map { |p| p[:id] }).to eq(%w[carol bob alice])
    end

    it "ranks ascending for Norsk Rummy" do
      players = [ { id: "alice", score: 100 }, { id: "bob", score: 50 } ]
      ranked = engine(game_type: "Norsk Rummy").send(:rank, players)
      expect(ranked.map { |p| p[:id] }).to eq(%w[bob alice])
      expect(ranked.first[:position]).to eq(0)
    end

    it "includes Table Tennis with desc ranking" do
      players = [ { id: "bob", score: 3 }, { id: "alice", score: 7 } ]
      ranked = engine(game_type: "Table Tennis").send(:rank, players)
      expect(ranked.map { |p| p[:id] }).to eq(%w[alice bob])
    end

    it "preserves player data alongside position" do
      players = [ { id: "bob", score: 10, team: "A" }, { id: "alice", score: 5 } ]
      ranked = engine(game_type: "Foosball").send(:rank, players)
      expect(ranked.first[:team]).to eq("A")
    end
  end

  describe "#compute_basis_points" do
    it "assigns 0 basis points to 1st place" do
      players = [ { id: "alice", score: 10 }, { id: "bob", score: 5 } ]
      ranked = engine(game_type: "Foosball").send(:rank, players)
      bp = engine.send(:compute_basis_points, ranked, 2)
      expect(bp["alice"]).to eq(0)
    end

    it "assigns 10000 basis points to 2nd place (2-player match)" do
      players = [ { id: "alice", score: 10 }, { id: "bob", score: 5 } ]
      ranked = engine(game_type: "Foosball").send(:rank, players)
      bp = engine.send(:compute_basis_points, ranked, 2)
      expect(bp["bob"]).to eq(10000)
    end

    it "handles ties with shared basis points" do
      # Bob and Carol tied at score 5, Alice at 10
      players = [ { id: "alice", score: 10 }, { id: "bob", score: 5 }, { id: "carol", score: 5 } ]
      ranked = engine(game_type: "Foosball").send(:rank, players)
      bp = engine.send(:compute_basis_points, ranked, 3)
      # Bob and Carol share avg(3750, 6250) = 5000
      expect(bp["bob"]).to eq(5000)
      expect(bp["carol"]).to eq(5000)
      expect(bp["alice"]).to eq(0)
    end

    it "uses ascending rank for Golf" do
      # Bob(0) and Carol(0) tied 1st → 0bp each; Alice(5) at position 2 → 6250bp
      players = [ { id: "alice", score: 5 }, { id: "bob", score: 0 }, { id: "carol", score: 0 } ]
      ranked = engine(game_type: "Golf").send(:rank, players)
      bp = engine.send(:compute_basis_points, ranked, 3)
      expect(bp["bob"]).to eq(0)
      expect(bp["carol"]).to eq(0)
      expect(bp["alice"]).to eq(6250)
    end

    it "handles Norsk Rummy with 3 players" do
      players = [ { id: "bob", score: 50 }, { id: "alice", score: 100 } ]
      ranked = engine(game_type: "Norsk Rummy").send(:rank, players)
      bp = engine.send(:compute_basis_points, ranked, 2)
      expect(bp["bob"]).to eq(0)
      expect(bp["alice"]).to eq(10000)
    end
  end

  describe "ranking direction" do
    it "ranks ascending for Golf (lowest score is 1st)" do
      points = { "alice" => 1000, "bob" => 1000, "carol" => 1000 }
      players = [ { id: "bob", score: 0 }, { id: "alice", score: 5 }, { id: "carol", score: 0 } ]

      settled = engine(game_type: "Golf").settle(points, players)

      # Bob and Carol tied for 1st (position 0), Alice is 3rd (position 2)
      # Alice stakes floor(1000 * 0.625 * 10 / 100) = 62
      # Pot = 62; split between Bob and Carol equally: 31 each
      expect(settled).to eq({ "alice" => 938, "bob" => 1031, "carol" => 1031 })
    end

    it "ranks descending for Foosball (highest score is 1st)" do
      points = { "alice" => 1000, "bob" => 1000 }
      players = [ { id: "alice", score: 21 }, { id: "bob", score: 15 } ]

      settled = engine(game_type: "Foosball").settle(points, players)

      # Alice 1st (0% stake), Bob 2nd (100% of 10% = 100)
      expect(settled).to eq({ "alice" => 1100, "bob" => 900 })
    end
  end

  describe "single player" do
    it "returns points unchanged for a single-player match" do
      points = { "alice" => 1000 }
      players = [ { id: "alice", score: 5 } ]

      settled = engine.settle(points, players)
      expect(settled).to eq({ "alice" => 1000 })
    end
  end

  describe "two players" do
    it "stakes 100% for 2nd place" do
      points = { "alice" => 1000, "bob" => 1000 }
      players = [ { id: "alice", score: 10 }, { id: "bob", score: 5 } ]

      settled = engine(game_type: "Foosball").settle(points, players)
      expect(settled).to eq({ "alice" => 1100, "bob" => 900 })
    end

    it "uses the stake percentage" do
      points = { "alice" => 1000, "bob" => 1000 }
      players = [ { id: "alice", score: 10 }, { id: "bob", score: 5 } ]

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
      players = [ { id: "alice", score: 10 }, { id: "bob", score: 5 }, { id: "carol", score: 0 } ]

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
      players = [ { id: "carol", score: 0 }, { id: "alice", score: 10 }, { id: "bob", score: 10 } ]

      settled = engine(game_type: "Golf").settle(points, players)

      expect(settled["carol"]).to eq(1100)
      expect(settled["alice"]).to eq(950)
      expect(settled["bob"]).to eq(950)
    end

    it "uses descending ranking for Foosball" do
      points = { "alice" => 1000, "bob" => 1000, "carol" => 1000 }
      players = [ { id: "alice", score: 21 }, { id: "bob", score: 15 }, { id: "carol", score: 8 } ]

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
      players = [ { id: "a", score: 20 }, { id: "b", score: 15 }, { id: "c", score: 10 }, { id: "d", score: 5 } ]

      settled = engine(game_type: "Foosball").settle(points, players)

      expect(settled["a"]).to eq(1100)
      expect(settled["b"]).to eq(975)
      expect(settled["c"]).to eq(960)
      expect(settled["d"]).to eq(965)
    end
  end

  describe "stakes come out of each player's own points" do
    it "stakes a percentage of the loser's current points, not a fixed amount" do
      # Bob is 2nd of 2 (100% basis): floor(2000 * 10 / 100) = 200 out of his own 2000.
      points = { "alice" => 500, "bob" => 2000 }
      players = [ { id: "alice", score: 10 }, { id: "bob", score: 5 } ]

      settled = engine(game_type: "Foosball").settle(points, players)
      expect(settled).to eq({ "alice" => 700, "bob" => 1800 })
    end

    it "leaves a broke loser and the winner untouched when the pot is empty" do
      points = { "alice" => 1000, "bob" => 0 }
      players = [ { id: "alice", score: 10 }, { id: "bob", score: 5 } ]

      settled = engine(game_type: "Foosball").settle(points, players)
      expect(settled).to eq({ "alice" => 1000, "bob" => 0 })
    end

    it "floors a stake that falls just short of a whole point" do
      # Bob 2nd of 2 (10000 basis) at 99%: 10101 * 10000 * 99 / 1_000_000 = 9999.99 -> 9999.
      points = { "alice" => 1000, "bob" => 10_101 }
      players = [ { id: "alice", score: 10 }, { id: "bob", score: 5 } ]

      settled = engine(game_type: "Foosball", stake_percentage: 99).settle(points, players)
      expect(settled).to eq({ "alice" => 10_999, "bob" => 102 })
    end

    it "floors each stake rather than rounding it up" do
      # Bob 2nd of 3 (3750 basis): 1009 * 3750 * 10 / 1_000_000 = 37.8 -> 37.
      points = { "alice" => 1000, "bob" => 1009, "carol" => 1000 }
      players = [ { id: "alice", score: 10 }, { id: "bob", score: 5 }, { id: "carol", score: 0 } ]

      settled = engine(game_type: "Foosball").settle(points, players)
      expect(settled["bob"]).to eq(1009 - 37)
    end
  end

  describe "an odd pot shared by several winners" do
    # Golf ranks ascending: Bob and Carol tie for 1st on 0, Alice is 3rd on 5.
    # Alice stakes floor(1010 * 6250 * 10 / 1_000_000) = 63, so the pot of 63
    # splits into 31 each with 1 point left over.
    let(:points) { { "alice" => 1010, "bob" => 1000, "carol" => 1000 } }
    let(:players) do
      [ { id: "alice", score: 5 }, { id: "bob", score: 0 }, { id: "carol", score: 0 } ]
    end
    let(:settled) { engine(game_type: "Golf").settle(points, players) }

    it "hands the remainder to a single winner, one point at a time" do
      expect(settled.values_at("bob", "carol").sort).to eq([ 1031, 1032 ])
    end

    it "creates no points while doing so" do
      expect(settled.values.sum).to eq(points.values.sum)
    end

    it "takes the whole pot out of the loser" do
      expect(settled["alice"]).to eq(1010 - 63)
    end
  end

  describe "zero-sum" do
    it "the total points never change" do
      points = { "a" => 1000, "b" => 1000, "c" => 1000, "d" => 1000, "e" => 1000 }
      players = [ { id: "a", score: 50 }, { id: "b", score: 40 }, { id: "c", score: 30 },
                 { id: "d", score: 20 }, { id: "e", score: 10 } ]

      settled = engine(game_type: "Foosball").settle(points, players)
      expect(settled.values.sum).to eq(points.values.sum)
    end
  end

  describe "negative scores" do
    it "accepts negative scores and ranks correctly" do
      # Golf ascending: Bob -50 (1st/0% stake), Alice 10 (2nd/37), Carol 30 (3rd/62)
      # Pot = 37 + 62 = 99. Bob gets 99 -> 1099.
      points = { "bob" => 1000, "alice" => 1000, "carol" => 1000 }
      players = [ { id: "bob", score: -50 }, { id: "alice", score: 10 }, { id: "carol", score: 30 } ]

      settled = engine(game_type: "Golf").settle(points, players)

      expect(settled["bob"]).to eq(1099)
      expect(settled["alice"]).to eq(963)
      expect(settled["carol"]).to eq(938)
    end
  end
end
