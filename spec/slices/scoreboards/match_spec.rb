require "rails_helper"

RSpec.describe Scoreboards::Match do
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

  it "treats a shut-out loser's zero score as the loser score" do
    match = described_class.new(match_id: "m-1", home_player_ids: [ "a" ], away_player_ids: [ "b" ], home_score: 21, away_score: 0)
    expect(match.winner_score).to eq(21)
    expect(match.loser_score).to eq(0)
  end
end
