require "rails_helper"

RSpec.describe Statistics::Match do
  describe "a home win" do
    subject(:match) do
      described_class.new(match_id: "m-1", home_player_ids: %w[a c], away_player_ids: %w[b d], home_score: 21, away_score: 8)
    end

    it "is a home win" do
      expect(match.home_win?).to be(true)
    end

    it "lists the home side as winners in home order" do
      expect(match.winners).to eq(%w[a c])
    end

    it "lists the away side as losers" do
      expect(match.losers).to eq(%w[b d])
    end

    it "reports the winner's and loser's game scores" do
      expect(match.winner_score).to eq(21)
      expect(match.loser_score).to eq(8)
    end

    it "lists all players, home side first" do
      expect(match.players).to eq(%w[a c b d])
    end
  end

  describe "an away win" do
    subject(:match) do
      described_class.new(match_id: "m-1", home_player_ids: [ "a" ], away_player_ids: [ "b" ], home_score: 3, away_score: 5)
    end

    it "is not a home win" do
      expect(match.home_win?).to be(false)
    end

    it "lists the away side as winners" do
      expect(match.winners).to eq([ "b" ])
    end

    it "lists the home side as losers" do
      expect(match.losers).to eq([ "a" ])
    end

    it "reports the winner's score first even when the away side won" do
      expect(match.winner_score).to eq(5)
      expect(match.loser_score).to eq(3)
    end
  end

  describe "#involves?" do
    subject(:match) do
      described_class.new(match_id: "m-1", home_player_ids: %w[a c], away_player_ids: %w[b d], home_score: 10, away_score: 4)
    end

    it "is true for every player on either side" do
      expect(%w[a c b d].map { |player| match.involves?(player) }).to all(be(true))
    end

    it "is false for a bystander" do
      expect(match.involves?("e")).to be(false)
    end
  end

  describe "#won_by?" do
    subject(:match) do
      described_class.new(match_id: "m-1", home_player_ids: %w[a c], away_player_ids: %w[b d], home_score: 4, away_score: 10)
    end

    it "is true for each player on the winning side" do
      expect(match.won_by?("b")).to be(true)
      expect(match.won_by?("d")).to be(true)
    end

    it "is false for the losers" do
      expect(match.won_by?("a")).to be(false)
      expect(match.won_by?("c")).to be(false)
    end
  end

  describe "#opponents_of" do
    subject(:match) do
      described_class.new(match_id: "m-1", home_player_ids: %w[a c], away_player_ids: %w[b d], home_score: 10, away_score: 4)
    end

    it "is the whole away side for a home player — the teammate is not an opponent" do
      expect(match.opponents_of("a")).to eq(%w[b d])
    end

    it "is the whole home side for an away player" do
      expect(match.opponents_of("d")).to eq(%w[a c])
    end
  end

  it "treats a shut-out loser's zero score as the loser score" do
    match = described_class.new(match_id: "m-1", home_player_ids: [ "a" ], away_player_ids: [ "b" ], home_score: 21, away_score: 0)
    expect(match.winner_score).to eq(21)
    expect(match.loser_score).to eq(0)
  end
end
