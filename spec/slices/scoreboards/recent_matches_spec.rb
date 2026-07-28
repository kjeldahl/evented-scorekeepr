require "rails_helper"

RSpec.describe Scoreboards::RecentMatches do
  def match(home, away, home_score, away_score)
    Scoreboards::Match.new(match_id: "m-1", home_player_ids: home, away_player_ids: away, home_score:, away_score:)
  end

  def names
    { "a" => "Alice", "b" => "Bob", "c" => "Carol", "d" => "Dave" }
  end

  def symbol_names
    { "a" => "Alice", "b" => "Bob", "c" => "Carol", "d" => "Dave" }
      .transform_keys(&:to_sym)
  end

  describe ".line" do
    it "phrases a 1v1 win as 'beats' with the winner's score first" do
      expect(described_class.line(match([ "a" ], [ "b" ], 21, 8), names)).to eq("Alice beats Bob 21-8")
    end

    it "puts the winning side first even when the away side won" do
      expect(described_class.line(match([ "b" ], [ "a" ], 8, 21), names)).to eq("Alice beats Bob 21-8")
    end

    it "phrases a 2v2 win as 'beat' joining each side with 'and'" do
      expect(described_class.line(match(%w[a c], %w[b d], 10, 4), names))
        .to eq("Alice and Carol beat Bob and Dave 10-4")
    end

    it "keeps each side's listed player order" do
      expect(described_class.line(match(%w[c a], %w[d b], 10, 4), names))
        .to eq("Carol and Alice beat Dave and Bob 10-4")
    end

    it "falls back to the player id when no name is known" do
      expect(described_class.line(match([ "ghost" ], [ "b" ], 21, 8), names)).to eq("ghost beats Bob 21-8")
    end
  end

  describe ".multiplayer_line" do
    def make_multi(scores)
      player_ids = scores.keys.map(&:to_sym)
      Scoreboards::MultiplayerMatch.new(match_id: "m-1", player_ids:,
                                         player_scores: scores.transform_keys(&:to_sym),
                                         deleted: false)
    end

    it "ranks descending for Foosball (highest score first)" do
      line = described_class.multiplayer_line(make_multi({ a: 10, b: 5, c: 3 }), symbol_names, "Foosball")
      expect(line).to eq("Alice (10), Bob (5), Carol (3)")
    end

    it "ranks ascending for Golf (lowest score first)" do
      line = described_class.multiplayer_line(make_multi({ a: 10, b: 5, c: 3 }), symbol_names, "Golf")
      expect(line).to eq("Carol (3), Bob (5), Alice (10)")
    end

    it "ranks ascending for Norsk Rummy" do
      line = described_class.multiplayer_line(make_multi({ a: 100, b: 50, c: 200 }), symbol_names, "Norsk Rummy")
      expect(line).to eq("Bob (50), Alice (100), Carol (200)")
    end

    it "falls back to player id for unknown names" do
      line = described_class.multiplayer_line(make_multi({ ghost: 10, b: 5 }), symbol_names)
      expect(line).to eq("ghost (10), Bob (5)")
    end

    it "uses default game_type Foosball when not specified" do
      line = described_class.multiplayer_line(make_multi({ a: 10, b: 5 }), symbol_names)
      expect(line).to eq("Alice (10), Bob (5)")
    end

    it "treats nil game_type as Foosball (default config returns desc ranking)" do
      line = described_class.multiplayer_line(make_multi({ a: 10, b: 5, c: 3 }), symbol_names, nil)
      expect(line).to eq("Alice (10), Bob (5), Carol (3)")
    end

    it "treats empty string game_type as Foosball" do
      line = described_class.multiplayer_line(make_multi({ a: 10, b: 5, c: 3 }), symbol_names, "")
      expect(line).to eq("Alice (10), Bob (5), Carol (3)")
    end
  end

  describe ".lines", :event_store do
    def user_registered(user_id:, name:)
      DcbEventStore::Event.new(
        type: "UserRegistered",
        data: { user_id:, name:, email: "#{user_id}@example.com", password_digest: "x" },
        tags: [ "user:#{user_id}", "user_email:#{user_id}@example.com" ]
      )
    end

    def match_registered(match_id:, home:, away:, home_score:, away_score:)
      DcbEventStore::Event.new(
        type: "MatchRegistered",
        data: { match_id:, league_id: "league-1", account_id: "acc-1", home_player_ids: home,
                away_player_ids: away, home_score:, away_score:, registered_by_user_id: home.first },
        tags: [ "match:#{match_id}", "league:league-1", "account:acc-1",
                *(home + away).map { |player| "player:#{player}" } ]
      )
    end

    it "is empty when no match was registered" do
      expect(described_class.lines("league-1")).to eq([])
    end

    it "lists the league's matches newest first with resolved names" do
      EventStore.append([
        user_registered(user_id: "a", name: "Alice"), user_registered(user_id: "b", name: "Bob"),
        user_registered(user_id: "c", name: "Carol"),
        match_registered(match_id: "m-1", home: [ "a" ], away: [ "b" ], home_score: 21, away_score: 8),
        match_registered(match_id: "m-2", home: [ "b" ], away: [ "c" ], home_score: 21, away_score: 15)
      ])
      expect(described_class.lines("league-1")).to eq([ "Bob beats Carol 21-15", "Alice beats Bob 21-8" ])
    end

    it "caps the list at the 5 most recent matches, dropping the oldest" do
      EventStore.append([
        user_registered(user_id: "a", name: "Alice"), user_registered(user_id: "b", name: "Bob"),
        *(1..6).map do |number|
          match_registered(match_id: "m-#{number}", home: [ "a" ], away: [ "b" ],
                           home_score: 21, away_score: number)
        end
      ])
      expect(described_class.lines("league-1")).to eq([
        "Alice beats Bob 21-6", "Alice beats Bob 21-5", "Alice beats Bob 21-4",
        "Alice beats Bob 21-3", "Alice beats Bob 21-2"
      ])
    end
  end

  describe ".entries", :event_store do
    def user_registered(user_id:, name:)
      DcbEventStore::Event.new(
        type: "UserRegistered",
        data: { user_id:, name:, email: "#{user_id}@example.com", password_digest: "x" },
        tags: [ "user:#{user_id}", "user_email:#{user_id}@example.com" ]
      )
    end

    def match_registered(match_id:, home:, away:, home_score:, away_score:)
      DcbEventStore::Event.new(
        type: "MatchRegistered",
        data: { match_id:, league_id: "league-1", account_id: "acc-1", home_player_ids: home,
                away_player_ids: away, home_score:, away_score:, registered_by_user_id: home.first },
        tags: [ "match:#{match_id}", "league:league-1", "account:acc-1",
                *(home + away).map { |player| "player:#{player}" } ]
      )
    end

    it "carries each match's id, line and players, newest first" do
      EventStore.append([
        user_registered(user_id: "a", name: "Alice"), user_registered(user_id: "b", name: "Bob"),
        match_registered(match_id: "m-1", home: [ "a" ], away: [ "b" ], home_score: 21, away_score: 8),
        match_registered(match_id: "m-2", home: [ "b" ], away: [ "a" ], home_score: 21, away_score: 15)
      ])
      expect(described_class.entries("league-1")).to eq([
        Scoreboards::RecentMatches::Entry.new(match_id: "m-2", line: "Bob beats Alice 21-15", player_ids: %w[b a]),
        Scoreboards::RecentMatches::Entry.new(match_id: "m-1", line: "Alice beats Bob 21-8", player_ids: %w[a b])
      ])
    end
  end
end
