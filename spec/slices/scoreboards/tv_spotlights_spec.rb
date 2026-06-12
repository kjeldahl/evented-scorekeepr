require "rails_helper"

RSpec.describe Scoreboards::TvSpotlights do
  def row(name, rank:, streak_kind:, streak_length:, points: 1000)
    Scoreboards::Standings::Row.new(
      rank:, player_id: name.downcase, name:, points:, played: streak_length,
      wins: 0, losses: 0, win_percentage: 0, points_for: 0, points_against: 0,
      streak: "#{streak_kind}#{streak_length}", streak_kind:, streak_length:
    )
  end

  describe ".leader" do
    it "is nil when there are no rows" do
      expect(described_class.leader([])).to be_nil
    end

    it "is the first row (rank 1) of the standings" do
      first = row("Alice", rank: 1, streak_kind: "W", streak_length: 1, points: 1100)
      second = row("Bob", rank: 2, streak_kind: "L", streak_length: 1, points: 900)
      expect(described_class.leader([ first, second ])).to eq(first)
    end
  end

  describe ".hot_streak" do
    it "is nil when there are no rows" do
      expect(described_class.hot_streak([])).to be_nil
    end

    it "is nil when the longest winning streak is only 1" do
      rows = [
        row("Alice", rank: 1, streak_kind: "W", streak_length: 1),
        row("Bob", rank: 2, streak_kind: "W", streak_length: 1)
      ]
      expect(described_class.hot_streak(rows)).to be_nil
    end

    it "ignores losing streaks of any length" do
      rows = [
        row("Alice", rank: 1, streak_kind: "W", streak_length: 1),
        row("Bob", rank: 2, streak_kind: "L", streak_length: 3)
      ]
      expect(described_class.hot_streak(rows)).to be_nil
    end

    it "picks a winning streak of exactly 2" do
      hot = row("Alice", rank: 1, streak_kind: "W", streak_length: 2)
      rows = [ hot, row("Bob", rank: 2, streak_kind: "L", streak_length: 2) ]
      expect(described_class.hot_streak(rows)).to eq(hot)
    end

    it "picks the longest winning streak even when ranked lower" do
      shorter = row("Alice", rank: 1, streak_kind: "W", streak_length: 2)
      longer = row("Bob", rank: 2, streak_kind: "W", streak_length: 3)
      expect(described_class.hot_streak([ shorter, longer ])).to eq(longer)
    end

    it "breaks streak-length ties towards the row ranked higher" do
      higher = row("Alice", rank: 1, streak_kind: "W", streak_length: 2)
      lower = row("Bob", rank: 2, streak_kind: "W", streak_length: 2)
      expect(described_class.hot_streak([ higher, lower ])).to eq(higher)
    end
  end
end
