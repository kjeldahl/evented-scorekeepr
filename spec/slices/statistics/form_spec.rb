require "rails_helper"

RSpec.describe Statistics::Form do
  def match(home, away, home_score = 21, away_score = 8)
    Statistics::Match.new(home_player_ids: home, away_player_ids: away, home_score:, away_score:)
  end

  describe ".tokens" do
    it "is empty for a player with no matches" do
      expect(described_class.tokens([ match([ "b" ], [ "c" ]) ], player_id: "a")).to eq([])
    end

    it "marks a win as W and a loss as L" do
      expect(described_class.tokens([ match([ "a" ], [ "b" ]) ], player_id: "a")).to eq([ "W" ])
      expect(described_class.tokens([ match([ "a" ], [ "b" ]) ], player_id: "b")).to eq([ "L" ])
    end

    it "marks a win for an away-side winner" do
      expect(described_class.tokens([ match([ "b" ], [ "a" ], 8, 21) ], player_id: "a")).to eq([ "W" ])
    end

    it "marks results for 2v2 participants too" do
      expect(described_class.tokens([ match(%w[a c], %w[b d], 10, 4) ], player_id: "c")).to eq([ "W" ])
      expect(described_class.tokens([ match(%w[a c], %w[b d], 10, 4) ], player_id: "d")).to eq([ "L" ])
    end

    it "skips matches the player was not part of" do
      tokens = described_class.tokens([ match([ "a" ], [ "b" ]), match([ "b" ], [ "c" ]) ], player_id: "a")
      expect(tokens).to eq([ "W" ])
    end

    it "lists the most recent result first" do
      tokens = described_class.tokens([ match([ "b" ], [ "a" ]), match([ "a" ], [ "b" ]) ], player_id: "a")
      expect(tokens).to eq(%w[W L])
    end

    it "keeps all five results when exactly five were played" do
      matches = [ match([ "a" ], [ "b" ]), match([ "b" ], [ "a" ]), match([ "a" ], [ "b" ]),
                  match([ "b" ], [ "a" ]), match([ "a" ], [ "b" ]) ]
      expect(described_class.tokens(matches, player_id: "a")).to eq(%w[W L W L W])
    end

    it "truncates to the last five, dropping the oldest result" do
      # Results in order: W W L W L W -> last five, newest first: W L W L W.
      matches = [ match([ "a" ], [ "b" ]), match([ "a" ], [ "c" ]), match([ "b" ], [ "a" ]),
                  match([ "a" ], [ "b" ]), match([ "c" ], [ "a" ]), match([ "a" ], [ "d" ]) ]
      expect(described_class.tokens(matches, player_id: "a")).to eq(%w[W L W L W])
    end

    it "truncates from the newest end, not the oldest" do
      # Results in order: L W W W W W -> the leading loss is the one dropped.
      matches = [ match([ "b" ], [ "a" ]), match([ "a" ], [ "b" ]), match([ "a" ], [ "b" ]),
                  match([ "a" ], [ "b" ]), match([ "a" ], [ "b" ]), match([ "a" ], [ "b" ]) ]
      expect(described_class.tokens(matches, player_id: "a")).to eq(%w[W W W W W])
    end
  end
end
