require "rails_helper"

RSpec.describe Scoreboards::MultiplayerGameType do
  describe "::CONFIG" do
    it "maps Foosball to desc ranking, 2-4 players" do
      expect(described_class::CONFIG["Foosball"]).to eq(
        ranking: :desc, min_players: 2, max_players: 4
      )
    end

    it "maps Table Tennis to desc ranking, 2-4 players" do
      expect(described_class::CONFIG["Table Tennis"]).to eq(
        ranking: :desc, min_players: 2, max_players: 4
      )
    end

    it "maps Golf to asc ranking, 1-8 players" do
      expect(described_class::CONFIG["Golf"]).to eq(
        ranking: :asc, min_players: 1, max_players: 8
      )
    end

    it "maps Norsk Rummy to asc ranking, 2-8 players" do
      expect(described_class::CONFIG["Norsk Rummy"]).to eq(
        ranking: :asc, min_players: 2, max_players: 8
      )
    end
  end

  describe "::find" do
    it "returns config for known game types" do
      expect(described_class.find("Foosball")[:ranking]).to eq(:desc)
      expect(described_class.find("Golf")[:ranking]).to eq(:asc)
      expect(described_class.find("Table Tennis")[:ranking]).to eq(:desc)
      expect(described_class.find("Norsk Rummy")[:ranking]).to eq(:asc)
    end

    it "returns DEFAULT for unknown game types" do
      config = described_class.find("Pool")
      expect(config).to eq(Scoreboards::MultiplayerGameType::DEFAULT)
      expect(config[:ranking]).to eq(:desc)
      expect(config[:min_players]).to eq(2)
      expect(config[:max_players]).to eq(4)
    end

    it "returns DEFAULT for a game type that was never registered" do
      config = described_class.find("Bridge")
      expect(config[:ranking]).to eq(:desc)
    end
  end

  describe "::DEFAULT" do
    it "defaults to desc ranking (legacy behavior)" do
      expect(Scoreboards::MultiplayerGameType::DEFAULT[:ranking]).to eq(:desc)
    end

    it "defaults to 2-4 players" do
      expect(Scoreboards::MultiplayerGameType::DEFAULT[:min_players]).to eq(2)
      expect(Scoreboards::MultiplayerGameType::DEFAULT[:max_players]).to eq(4)
    end
  end
end
