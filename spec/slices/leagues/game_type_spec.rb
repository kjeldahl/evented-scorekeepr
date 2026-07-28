require "rails_helper"

RSpec.describe Leagues::GameType do
  describe "::TYPES" do
    it "lists Foosball" do
      values = described_class::TYPES.map(&:last)
      expect(values).to include("Foosball")
    end

    it "lists Table Tennis" do
      values = described_class::TYPES.map(&:last)
      expect(values).to include("Table Tennis")
    end

    it "lists Norsk Rummy" do
      values = described_class::TYPES.map(&:last)
      expect(values).to include("Norsk Rummy")
    end

    it "includes all known game types" do
      values = described_class::TYPES.map(&:last)
      expect(values).to eq([ "Foosball", "Table Tennis", "Pool", "Darts", "Golf", "Norsk Rummy" ])
    end

    it "uses label and value pairs suitable for form select helpers" do
      described_class::TYPES.each do |(label, value)|
        expect(label).to be_a(String)
        expect(value).to be_a(String)
      end
    end

    it "is frozen" do
      expect(described_class::TYPES.frozen?).to be(true)
    end
  end
end