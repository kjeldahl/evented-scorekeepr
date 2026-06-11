require "rails_helper"

RSpec.describe Statistics::MatchLine do
  def match(home, away, home_score, away_score)
    Statistics::Match.new(home_player_ids: home, away_player_ids: away, home_score:, away_score:)
  end

  def names
    { "a" => "Alice", "b" => "Bob", "c" => "Carol", "d" => "Dave" }
  end

  describe ".format" do
    it "phrases a 1v1 win as 'beats' with the winner's score first" do
      expect(described_class.format(match([ "a" ], [ "b" ], 21, 8), names)).to eq("Alice beats Bob 21-8")
    end

    it "puts the winning side first even when the away side won" do
      expect(described_class.format(match([ "b" ], [ "a" ], 8, 21), names)).to eq("Alice beats Bob 21-8")
    end

    it "phrases a 2v2 win as 'beat' joining each side with 'and'" do
      expect(described_class.format(match(%w[a c], %w[b d], 10, 4), names))
        .to eq("Alice and Carol beat Bob and Dave 10-4")
    end

    it "keeps each side's listed player order" do
      expect(described_class.format(match(%w[c a], %w[d b], 10, 4), names))
        .to eq("Carol and Alice beat Dave and Bob 10-4")
    end

    it "falls back to the player id when no name is known" do
      expect(described_class.format(match([ "ghost" ], [ "b" ], 21, 8), names)).to eq("ghost beats Bob 21-8")
    end
  end
end
