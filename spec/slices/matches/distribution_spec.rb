require "rails_helper"

RSpec.describe Matches::Distribution do
  describe ".basis_point_for" do
    it "returns 0 for position 0 (1st place)" do
      expect(described_class.basis_point_for(2, 0)).to eq(0)
    end

    it "returns the basis point for a paying position" do
      expect(described_class.basis_point_for(3, 2)).to eq(6250)
    end

    it "returns 0 for a position beyond the distribution" do
      expect(described_class.basis_point_for(3, 5)).to eq(0)
    end

    it "returns 0 for an unknown player count" do
      expect(described_class.basis_point_for(20, 1)).to eq(0)
    end
  end

  describe ".ratio_for" do
    it "returns 0 for position 0 (1st place)" do
      expect(described_class.ratio_for(3, 0)).to eq(0.0)
    end

    it "returns the correct ratio for position 1 in 3-player distribution" do
      expect(described_class.ratio_for(3, 1)).to eq(0.375)
    end

    it "returns the correct ratio for position 2 in 3-player distribution" do
      expect(described_class.ratio_for(3, 2)).to eq(0.625)
    end

    it "returns 0 for a position beyond the distribution" do
      expect(described_class.ratio_for(3, 5)).to eq(0.0)
    end

    it "returns 1.0 for 2-player position 1 (2nd place)" do
      expect(described_class.ratio_for(2, 1)).to eq(1.0)
    end
  end
end
