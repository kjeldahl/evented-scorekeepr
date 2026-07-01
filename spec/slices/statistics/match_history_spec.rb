require "rails_helper"

RSpec.describe Statistics::MatchHistory do
  def match(home, away, home_score = 21, away_score = 8)
    Statistics::Match.new(match_id: "m-1", home_player_ids: home, away_player_ids: away, home_score:, away_score:)
  end

  def names
    { "a" => "Alice", "b" => "Bob", "c" => "Carol", "d" => "Dave" }
  end

  def entries(*matches)
    Statistics::StakeLedger.new(starting_points: 1000, stake_percentage: 10).entries(matches)
  end

  def rows(player_id, *matches)
    described_class.rows(entries(*matches), player_id:, names:)
  end

  describe ".rows" do
    it "is empty for a player with no matches" do
      expect(rows("c", match([ "a" ], [ "b" ]))).to eq([])
    end

    it "pairs the result line with the player's balance after the match" do
      expect(rows("a", match([ "a" ], [ "b" ]))).to eq([
        described_class::Row.new(line: "Alice beats Bob 21-8", points_after: 1100)
      ])
    end

    it "shows the loser's balance after the same match" do
      expect(rows("b", match([ "a" ], [ "b" ])).sole.points_after).to eq(900)
    end

    it "lists the player's matches newest first with their running balance" do
      result = rows("a", match([ "a" ], [ "b" ]), match([ "b" ], [ "a" ], 21, 19))
      expect(result.map(&:line)).to eq([ "Bob beats Alice 21-19", "Alice beats Bob 21-8" ])
      expect(result.map(&:points_after)).to eq([ 990, 1100 ])
    end

    it "skips matches the player was not part of without breaking the balances" do
      result = rows("a", match([ "a" ], [ "b" ]), match([ "b" ], [ "c" ], 21, 15), match([ "a" ], [ "c" ], 21, 18))
      expect(result.map(&:points_after)).to eq([ 1190, 1100 ])
    end

    it "uses the running balance from the stake fold for a 2v2 with remainder" do
      # Bob stakes 101, Dave 100; pot 201 -> Alice (listed first) 990 + 101 = 1091.
      result = rows("a", match([ "a" ], [ "b" ]), match([ "b" ], [ "a" ], 21, 19), match(%w[a c], %w[b d], 10, 4))
      expect(result.first).to eq(described_class::Row.new(line: "Alice and Carol beat Bob and Dave 10-4",
                                                          points_after: 1091))
    end
  end

  describe ".page" do
    def page_of(player_id, *matches, number: 1)
      described_class.page(entries(*matches), player_id:, names:, number:)
    end

    def matches(count)
      Array.new(count) { match([ "a" ], [ "b" ]) }
    end

    it "is a single full page when the history fits exactly" do
      page = page_of("a", *matches(10))
      expect(page).to have_attributes(number: 1, pages: 1)
      expect(page.rows.size).to eq(10)
    end

    it "puts the ten newest matches on page one and the rest after" do
      page = page_of("a", *matches(11))
      expect(page).to have_attributes(number: 1, pages: 2)
      expect(page.rows.size).to eq(10)
    end

    it "keeps newest-first order across pages: the last page holds the oldest match" do
      # Eleven Alice wins: the very first one left her at 1100, and only
      # that oldest match spills onto page two.
      page = page_of("a", *matches(11), number: 2)
      expect(page.rows.sole.points_after).to eq(1100)
    end

    it "clamps a page number past the end to the last page" do
      expect(page_of("a", *matches(11), number: 99)).to have_attributes(number: 2, pages: 2)
    end

    it "clamps a page number below one to the first page" do
      expect(page_of("a", *matches(3), number: 0)).to have_attributes(number: 1, pages: 1)
    end

    it "is an empty single page for a player with no matches" do
      page = page_of("c", match([ "a" ], [ "b" ]))
      expect(page).to eq(described_class::Page.new(rows: [], number: 1, pages: 1))
    end
  end
end
