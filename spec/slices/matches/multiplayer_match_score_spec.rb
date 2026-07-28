require "rails_helper"

RSpec.describe Matches::MultiplayerMatchScore do
  describe ".parse" do
    it "parses an integer string" do
      expect(described_class.parse("21")).to eq(21)
    end

    it "parses a negative integer string" do
      expect(described_class.parse("-50")).to eq(-50)
    end

    it "parses zero" do
      expect(described_class.parse("0")).to eq(0)
    end

    it "returns nil for a non-integer string" do
      expect(described_class.parse("10.5")).to be_nil
    end

    it "returns nil for a non-numeric string" do
      expect(described_class.parse("abc")).to be_nil
    end

    it "accepts an integer directly" do
      expect(described_class.parse(42)).to eq(42)
    end

    it "is nil for a float, which is not an integer score (never truncates)" do
      expect(described_class.parse(10.5)).to be_nil
    end
  end

  describe ".parse_all" do
    it "parses every score, keeping the player keys" do
      expect(described_class.parse_all({ "alice" => "21", "bob" => "-50" }))
        .to eq({ "alice" => 21, "bob" => -50 })
    end

    it "leaves an already-integer score alone" do
      expect(described_class.parse_all({ "alice" => 7 })).to eq({ "alice" => 7 })
    end

    it "is nil for a score that is not an integer" do
      expect(described_class.parse_all({ "alice" => "10.5" })).to eq({ "alice" => nil })
    end
  end

  describe ".rejection" do
    it "returns nil when all scores are valid integers" do
      expect(described_class.rejection({ "alice" => "10", "bob" => "5" })).to be_nil
    end

    it "returns nil when scores are negative integers" do
      expect(described_class.rejection({ "alice" => "-50", "bob" => "10" })).to be_nil
    end

    it "rejects a fractional score" do
      expect(described_class.rejection({ "alice" => "10.5", "bob" => "5" }))
        .to eq(Result.failure("scores must be integers"))
    end

    it "rejects a non-numeric score" do
      expect(described_class.rejection({ "alice" => "abc", "bob" => "5" }))
        .to eq(Result.failure("scores must be integers"))
    end
  end

  describe ".valid?" do
    it "is true for valid scores" do
      expect(described_class.valid?(%w[10 5 0].to_h { |s| [ "p-#{s}", s ] })).to be(true)
    end

    it "is false for a fractional score" do
      expect(described_class.valid?(%w[10 5 10.5].to_h { |s| [ "p-#{s}", s ] })).to be(false)
    end
  end
end
