require "rails_helper"

RSpec.describe Leagues::LeagueMode do
  describe "::MODES" do
    it "offers the match mode" do
      expect(described_class::MODES).to include([ "Match", "match" ])
    end

    it "offers the multiplayer mode" do
      expect(described_class::MODES).to include([ "Multiplayer", "multiplayer" ])
    end

    it "offers match first, so the form defaults to a match league" do
      expect(described_class::MODES.map(&:last)).to eq(%w[match multiplayer])
    end

    it "is frozen" do
      expect(described_class::MODES.frozen?).to be(true)
    end
  end

  describe ".chosen" do
    it "keeps an explicit multiplayer choice" do
      expect(described_class.chosen("multiplayer")).to eq("multiplayer")
    end

    it "keeps an explicit match choice" do
      expect(described_class.chosen("match")).to eq("match")
    end

    it "strips surrounding whitespace before comparing" do
      expect(described_class.chosen(" multiplayer ")).to eq("multiplayer")
    end

    it "falls back to match when nothing was chosen" do
      expect(described_class.chosen(nil)).to eq("match")
    end

    it "falls back to match for a blank choice" do
      expect(described_class.chosen(" ")).to eq("match")
    end

    it "falls back to match for an unknown mode" do
      expect(described_class.chosen("knockout")).to eq("match")
    end
  end
end
