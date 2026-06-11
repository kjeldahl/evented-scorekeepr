require "rails_helper"

RSpec.describe Statistics::HeadToHead do
  def match(home, away, home_score = 21, away_score = 8)
    Statistics::Match.new(home_player_ids: home, away_player_ids: away, home_score:, away_score:)
  end

  def names
    { "a" => "Alice", "b" => "Bob", "c" => "Carol", "d" => "Dave", "e" => "Eve" }
  end

  def rows(*matches, player_id: "a")
    described_class.rows(matches, player_id:, names:)
  end

  def row(opponent:, played:, won:, lost:)
    described_class::Row.new(opponent:, played:, won:, lost:)
  end

  describe ".rows" do
    it "is empty for a player with no matches" do
      expect(rows(match([ "b" ], [ "c" ]))).to eq([])
    end

    it "counts a win against the opponent" do
      expect(rows(match([ "a" ], [ "b" ]))).to eq([ row(opponent: "Bob", played: 1, won: 1, lost: 0) ])
    end

    it "counts a loss against the opponent" do
      expect(rows(match([ "b" ], [ "a" ]))).to eq([ row(opponent: "Bob", played: 1, won: 0, lost: 1) ])
    end

    it "accumulates wins and losses against the same opponent" do
      result = rows(match([ "a" ], [ "b" ]), match([ "b" ], [ "a" ]), match([ "a" ], [ "b" ]))
      expect(result).to eq([ row(opponent: "Bob", played: 3, won: 2, lost: 1) ])
    end

    it "counts every player on the other side of a 2v2, never the teammate" do
      # Eve is Alice's teammate, so only Bob and Dave are opponents.
      result = rows(match(%w[a e], %w[b d], 10, 4))
      expect(result).to contain_exactly(row(opponent: "Bob", played: 1, won: 1, lost: 0),
                                        row(opponent: "Dave", played: 1, won: 1, lost: 0))
    end

    it "counts the home side as opponents when the player was away" do
      result = rows(match(%w[b d], %w[a e], 10, 4))
      expect(result).to contain_exactly(row(opponent: "Bob", played: 1, won: 0, lost: 1),
                                        row(opponent: "Dave", played: 1, won: 0, lost: 1))
    end

    it "orders by most played first" do
      result = rows(match([ "a" ], [ "b" ]), match([ "b" ], [ "a" ]), match([ "a" ], [ "c" ]))
      expect(result.map(&:opponent)).to eq(%w[Bob Carol])
    end

    it "orders opponents tied on played by name" do
      result = rows(match([ "a" ], [ "d" ]), match([ "a" ], [ "c" ]), match([ "a" ], [ "b" ]))
      expect(result.map(&:opponent)).to eq(%w[Bob Carol Dave])
    end

    it "breaks the tie by name even when the ids sort the other way" do
      tied = described_class.rows([ match([ "a" ], [ "a-id" ]), match([ "a" ], [ "z-id" ]) ],
                                  player_id: "a", names: { "a-id" => "Zoe", "z-id" => "Anna" })
      expect(tied.map(&:opponent)).to eq(%w[Anna Zoe])
    end

    it "falls back to the player id when no name is known" do
      expect(rows(match([ "a" ], [ "ghost" ])).sole.opponent).to eq("ghost")
    end
  end
end
