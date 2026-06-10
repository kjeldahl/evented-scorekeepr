require "rails_helper"

RSpec.describe Scoreboards::RecentMatches do
  def match(home, away, home_score, away_score)
    Scoreboards::Match.new(home_player_ids: home, away_player_ids: away, home_score:, away_score:)
  end

  def names
    { "a" => "Alice", "b" => "Bob", "c" => "Carol", "d" => "Dave" }
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
  end
end
