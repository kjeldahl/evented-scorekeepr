require "rails_helper"

RSpec.describe Scoreboards::MultiplayerDistribution do
  describe ".basis_point_for" do
    it "returns 0 for position 0 (1st place) with 2 players" do
      expect(described_class.basis_point_for(2, 0)).to eq(0)
    end

    it "returns the basis point for position 1 in a 2-player match" do
      expect(described_class.basis_point_for(2, 1)).to eq(10000)
    end

    it "returns the basis point for position 2 in a 3-player match" do
      expect(described_class.basis_point_for(3, 2)).to eq(6250)
    end

    it "returns 0 for a position beyond the distribution" do
      expect(described_class.basis_point_for(3, 5)).to eq(0)
    end

    it "returns 0 for an unknown player count" do
      expect(described_class.basis_point_for(20, 0)).to eq(0)
    end

    it "returns 0 for a position beyond an unknown player count" do
      expect(described_class.basis_point_for(20, 15)).to eq(0)
    end

    it "returns all basis points for an 8-player match" do
      expect(described_class.basis_point_for(8, 0)).to eq(0)
      expect(described_class.basis_point_for(8, 1)).to eq(1100)
      expect(described_class.basis_point_for(8, 2)).to eq(1700)
      expect(described_class.basis_point_for(8, 3)).to eq(2100)
      expect(described_class.basis_point_for(8, 4)).to eq(1900)
      expect(described_class.basis_point_for(8, 5)).to eq(1600)
      expect(described_class.basis_point_for(8, 6)).to eq(1200)
      expect(described_class.basis_point_for(8, 7)).to eq(400)
    end
  end

  describe "BASIS_POINT invariant" do
    it "sums to 10000 for each player count" do
      described_class::BASIS_POINT.each do |count, values|
        expect(values.sum).to eq(10000), "player count #{count} sums to #{values.sum}, not 10000"
      end
    end
  end
end
