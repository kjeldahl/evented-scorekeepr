require "rails_helper"

RSpec.describe Scoreboards::Standings do
  subject(:standings) { described_class.new(starting_points: 1000, stake_percentage: 10) }

  def names
    { "alice" => "Alice", "bob" => "Bob", "carol" => "Carol", "dave" => "Dave", "eve" => "Eve" }
  end

  def match(home, away, home_score, away_score)
    Scoreboards::Match.new(home_player_ids: home, away_player_ids: away, home_score:, away_score:)
  end

  def table(*matches)
    standings.table(matches, names:)
  end

  def row_for(rows, name)
    rows.find { |row| row.name == name } or raise "#{name} not in #{rows.map(&:name).inspect}"
  end

  it "is empty before any match" do
    expect(table).to eq([])
  end

  describe "a single 1v1 match" do
    let(:rows) { table(match([ "alice" ], [ "bob" ], 21, 8)) }

    it "seeds both players with the starting points and settles the stake" do
      expect(row_for(rows, "Alice").points).to eq(1100)
      expect(row_for(rows, "Bob").points).to eq(900)
    end

    it "lists only players who appeared in a match" do
      expect(rows.map(&:name)).to eq(%w[Alice Bob])
    end

    it "counts played, wins and losses" do
      expect(row_for(rows, "Alice")).to have_attributes(played: 1, wins: 1, losses: 0)
      expect(row_for(rows, "Bob")).to have_attributes(played: 1, wins: 0, losses: 1)
    end

    it "shows W1 / L1 streaks" do
      expect(row_for(rows, "Alice").streak).to eq("W1")
      expect(row_for(rows, "Bob").streak).to eq("L1")
    end

    it "attributes the game points for and against" do
      expect(row_for(rows, "Alice")).to have_attributes(points_for: 21, points_against: 8)
      expect(row_for(rows, "Bob")).to have_attributes(points_for: 8, points_against: 21)
    end

    it "ranks the winner first" do
      expect(rows.map { |row| [ row.rank, row.name ] }).to eq([ [ 1, "Alice" ], [ 2, "Bob" ] ])
    end

    it "carries the player id on each row" do
      expect(row_for(rows, "Alice").player_id).to eq("alice")
    end
  end

  describe "custom league settings" do
    it "seeds players with the league's starting points and floors the stake" do
      rows = described_class.new(starting_points: 1015, stake_percentage: 10)
                            .table([ match([ "alice" ], [ "bob" ], 21, 8) ], names:)
      expect(row_for(rows, "Alice").points).to eq(1116)
      expect(row_for(rows, "Bob").points).to eq(914)
    end

    it "uses the league's stake percentage" do
      rows = described_class.new(starting_points: 1000, stake_percentage: 20)
                            .table([ match([ "alice" ], [ "bob" ], 21, 12) ], names:)
      expect(row_for(rows, "Alice").points).to eq(1200)
      expect(row_for(rows, "Bob").points).to eq(800)
    end
  end

  describe "a sequence of matches" do
    # Match 1: Alice beats Bob 21-8    -> Bob stakes 100: Alice 1100, Bob 900
    # Match 2: Bob beats Carol 21-15   -> Carol enters at 1000, stakes 100: Carol 900, Bob 1000
    # Match 3: Alice beats Carol 21-18 -> Carol stakes 10% of 900 = 90: Carol 810, Alice 1190
    let(:rows) do
      table(match([ "alice" ], [ "bob" ], 21, 8),
            match([ "bob" ], [ "carol" ], 21, 15),
            match([ "alice" ], [ "carol" ], 21, 18))
    end

    it "applies the matches in order, staking current points" do
      expect(rows.map { |row| [ row.rank, row.name, row.points ] })
        .to eq([ [ 1, "Alice", 1190 ], [ 2, "Bob", 1000 ], [ 3, "Carol", 810 ] ])
    end

    it "seeds a player at the starting points when they first appear mid-league" do
      # Carol staked 100 in match 2 (10% of her seed 1000), not of anything else.
      expect(row_for(rows, "Carol").points_against).to eq(42)
      expect(row_for(rows, "Carol").points).to eq(810)
    end

    it "accumulates statistics across matches" do
      expect(row_for(rows, "Alice")).to have_attributes(played: 2, wins: 2, losses: 0,
                                                        points_for: 42, points_against: 26)
      expect(row_for(rows, "Bob")).to have_attributes(played: 2, wins: 1, losses: 1,
                                                      points_for: 29, points_against: 36)
      expect(row_for(rows, "Carol")).to have_attributes(played: 2, wins: 0, losses: 2,
                                                        points_for: 33, points_against: 42)
    end

    it "computes the win percentage" do
      expect(rows.map(&:win_percentage)).to eq([ 100, 50, 0 ])
    end

    it "tracks the current streak per player" do
      expect(row_for(rows, "Alice").streak).to eq("W2")
      expect(row_for(rows, "Bob").streak).to eq("W1")
      expect(row_for(rows, "Carol").streak).to eq("L2")
    end
  end

  describe "streaks" do
    it "resets when the result flips" do
      rows = table(match([ "alice" ], [ "bob" ], 21, 8), match([ "bob" ], [ "alice" ], 21, 19))
      expect(row_for(rows, "Alice").streak).to eq("L1")
      expect(row_for(rows, "Bob").streak).to eq("W1")
    end

    it "grows while the result repeats" do
      rows = table(match([ "alice" ], [ "bob" ], 21, 8),
                   match([ "alice" ], [ "bob" ], 21, 14),
                   match([ "alice" ], [ "bob" ], 21, 17))
      expect(row_for(rows, "Alice").streak).to eq("W3")
      expect(row_for(rows, "Bob").streak).to eq("L3")
    end

    it "counts only the most recent run" do
      rows = table(match([ "bob" ], [ "alice" ], 21, 8),
                   match([ "alice" ], [ "bob" ], 21, 14),
                   match([ "alice" ], [ "bob" ], 21, 17))
      expect(row_for(rows, "Alice").streak).to eq("W2")
    end
  end

  it "shrinks repeated stakes so points never go negative" do
    rows = table(match([ "alice" ], [ "bob" ], 21, 8),
                 match([ "alice" ], [ "bob" ], 21, 14),
                 match([ "alice" ], [ "bob" ], 21, 17))
    expect(row_for(rows, "Bob").points).to eq(729)
    expect(row_for(rows, "Alice").points).to eq(1271)
  end

  describe "2v2 matches" do
    it "splits an even pot between the winners and seeds all four players" do
      rows = table(match(%w[alice carol], %w[bob dave], 10, 4))
      expect(rows.map { |row| [ row.name, row.points ] })
        .to eq([ [ "Alice", 1100 ], [ "Carol", 1100 ], [ "Bob", 900 ], [ "Dave", 900 ] ])
    end

    it "hands an odd pot's remainder to the first-listed winner (mixed loser points)" do
      # Bob 1010, Carol 1000 -> stakes 101 + 100 = 201; Dave (listed first) 1101, Eve 1100.
      rows = table(match([ "alice" ], [ "bob" ], 21, 8),
                   match([ "bob" ], [ "alice" ], 21, 19),
                   match(%w[dave eve], %w[bob carol], 10, 7))
      expect(row_for(rows, "Dave").points).to eq(1101)
      expect(row_for(rows, "Eve").points).to eq(1100)
      expect(row_for(rows, "Bob").points).to eq(909)
      expect(row_for(rows, "Carol").points).to eq(900)
    end

    it "uses the winning side's listed order when the away side wins" do
      rows = table(match([ "alice" ], [ "bob" ], 21, 8),
                   match([ "bob" ], [ "alice" ], 21, 19),
                   match(%w[bob carol], %w[eve dave], 7, 10))
      expect(row_for(rows, "Eve").points).to eq(1101)
      expect(row_for(rows, "Dave").points).to eq(1100)
    end

    it "credits each player on a side with the side's game score" do
      rows = table(match(%w[alice carol], %w[bob dave], 10, 4))
      expect(row_for(rows, "Carol")).to have_attributes(points_for: 10, points_against: 4)
      expect(row_for(rows, "Dave")).to have_attributes(points_for: 4, points_against: 10)
    end
  end

  describe "ranking" do
    it "orders by points descending" do
      rows = table(match([ "alice" ], [ "bob" ], 21, 8), match([ "bob" ], [ "alice" ], 21, 19))
      expect(rows.map { |row| [ row.rank, row.name, row.points ] })
        .to eq([ [ 1, "Bob", 1010 ], [ 2, "Alice", 990 ] ])
    end

    it "orders tied players by name with sequential ranks" do
      rows = table(match([ "alice" ], [ "bob" ], 21, 8), match([ "carol" ], [ "dave" ], 21, 8))
      expect(rows.map { |row| [ row.rank, row.name ] })
        .to eq([ [ 1, "Alice" ], [ 2, "Carol" ], [ 3, "Bob" ], [ 4, "Dave" ] ])
    end

    it "breaks ties by name even when ids and arrival order sort the other way" do
      names = { "a-id" => "Zoe", "z-id" => "Anna" }
      rows = standings.table([ match([ "a-id" ], [ "x" ], 21, 8), match([ "z-id" ], [ "y" ], 21, 8) ],
                             names: names.merge("x" => "Xav", "y" => "Yan"))
      expect(rows.first(2).map(&:name)).to eq(%w[Anna Zoe])
    end

    it "breaks ties between unknown players by their id" do
      rows = standings.table([ match([ "b-id" ], [ "y" ], 21, 8), match([ "a-id" ], [ "x" ], 21, 8) ],
                             names: {})
      expect(rows.map(&:name)).to eq(%w[a-id b-id x y])
    end

    it "falls back to the player id when no name is known" do
      rows = standings.table([ match([ "alice" ], [ "ghost" ], 21, 8) ], names:)
      expect(row_for(rows, "ghost").name).to eq("ghost")
    end
  end

  describe "win percentage rounding" do
    it "rounds 1 of 3 to 33" do
      rows = table(match([ "alice" ], [ "bob" ], 21, 8),
                   match([ "bob" ], [ "alice" ], 21, 14),
                   match([ "bob" ], [ "alice" ], 21, 17))
      expect(row_for(rows, "Alice").win_percentage).to eq(33)
      expect(row_for(rows, "Bob").win_percentage).to eq(67)
    end
  end
end
