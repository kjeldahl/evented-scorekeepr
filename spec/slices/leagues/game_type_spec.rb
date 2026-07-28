require "rails_helper"

RSpec.describe Leagues::GameType do
  describe "::TYPES" do
    it "includes all game types that have a scoreboard config" do
      expect(described_class::TYPES.map(&:last)).to include("Foosball")
      expect(described_class::TYPES.map(&:last)).to include("Golf")
      expect(described_class::TYPES.map(&:last)).to include("Table Tennis")
      expect(described_class::TYPES.map(&:last)).to include("Norsk Rummy")
    end

    it "also lists Pool and Darts (types without special config)" do
      expect(described_class::TYPES.map(&:last)).to include("Pool")
      expect(described_class::TYPES.map(&:last)).to include("Darts")
    end

    it "is an array of [label, value] pairs" do
      expect(described_class::TYPES).to be_an(Array)
      described_class::TYPES.each do |label, value|
        expect(label).to be_a(String)
        expect(value).to be_a(String)
      end
    end
  end
end
