require "rails_helper"

RSpec.describe Matches::MatchScore do
  describe ".parse" do
    it "parses an integer string, ignoring surrounding whitespace" do
      expect(described_class.parse("  21 ")).to eq(21)
    end

    it "parses an integer as itself" do
      expect(described_class.parse(21)).to eq(21)
    end

    it "is nil for blank input" do
      expect(described_class.parse("")).to be_nil
    end

    it "is nil for a non-integer string" do
      expect(described_class.parse("abc")).to be_nil
    end

    it "is nil for a decimal string (scores are whole numbers)" do
      expect(described_class.parse("21.5")).to be_nil
    end
  end

  describe ".rejection" do
    it "is nil for a valid, non-drawn pair" do
      expect(described_class.rejection(21, 8)).to be_nil
    end

    it "accepts zero as a non-negative score" do
      expect(described_class.rejection(11, 0)).to be_nil
    end

    it "rejects a nil score (blank or non-integer input)" do
      expect(described_class.rejection(nil, 8))
        .to eq(Result.failure("scores must be non-negative integers"))
    end

    it "rejects a negative home score" do
      expect(described_class.rejection(-1, 8))
        .to eq(Result.failure("scores must be non-negative integers"))
    end

    it "rejects a negative away score" do
      expect(described_class.rejection(21, -3))
        .to eq(Result.failure("scores must be non-negative integers"))
    end

    it "rejects a draw over a valid non-negative pair" do
      expect(described_class.rejection(10, 10))
        .to eq(Result.failure("draws are not allowed"))
    end

    it "reports the non-negative error before the draw error" do
      expect(described_class.rejection(-1, -1))
        .to eq(Result.failure("scores must be non-negative integers"))
    end
  end
end
