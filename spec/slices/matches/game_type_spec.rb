require "rails_helper"

RSpec.describe Matches::GameType do
  describe ".find" do
    it "returns the config for Foosball" do
      expect(described_class.find("Foosball")).to eq(
        { ranking: :desc, min_players: 2, max_players: 4 }
      )
    end

    it "returns the config for Table Tennis" do
      expect(described_class.find("Table Tennis")).to eq(
        { ranking: :desc, min_players: 2, max_players: 4 }
      )
    end

    it "returns the config for Golf" do
      expect(described_class.find("Golf")).to eq(
        { ranking: :asc, min_players: 1, max_players: 8 }
      )
    end

    it "returns default config for unknown game types" do
      expect(described_class.find("Unknown")).to eq(
        { ranking: :desc, min_players: 2, max_players: 4 }
      )
    end
  end

  describe ".valid_player_count?" do
    it "accepts 2 for Foosball" do
      expect(described_class.valid_player_count?("Foosball", 2)).to be(true)
    end

    it "rejects 1 for Foosball" do
      expect(described_class.valid_player_count?("Foosball", 1)).to be(false)
    end

    it "accepts 1 for Golf" do
      expect(described_class.valid_player_count?("Golf", 1)).to be(true)
    end

    it "accepts 8 for Golf" do
      expect(described_class.valid_player_count?("Golf", 8)).to be(true)
    end

    it "rejects 9 for Golf" do
      expect(described_class.valid_player_count?("Golf", 9)).to be(false)
    end
  end
end