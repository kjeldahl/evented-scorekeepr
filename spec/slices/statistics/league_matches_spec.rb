require "rails_helper"

RSpec.describe Statistics::LeagueMatches do
  def match_registered(match_id: "m-1", league_id: "league-1", home: [ "a" ], away: [ "b" ],
                       home_score: 21, away_score: 8)
    DcbEventStore::Event.new(
      type: "MatchRegistered",
      data: { match_id:, league_id:, account_id: "acc-1", home_player_ids: home, away_player_ids: away,
              home_score:, away_score:, registered_by_user_id: "a" },
      tags: [ "match:#{match_id}", "league:#{league_id}", "account:acc-1",
              *(home + away).map { |player| "player:#{player}" } ]
    )
  end

  describe ".projection" do
    subject(:projection) { described_class.projection("league-1") }

    it "starts with no matches" do
      expect(projection.initial_state).to eq([])
    end

    it "folds MatchRegistered into Match values in event order" do
      matches = projection.fold([ match_registered, match_registered(match_id: "m-2", home_score: 3, away_score: 5) ])
      expect(matches.map(&:home_score)).to eq([ 21, 3 ])
    end

    it "carries the sides and scores onto the Match value" do
      match = projection.fold([ match_registered(home: %w[a c], away: %w[b d], home_score: 10, away_score: 4) ]).sole
      expect(match).to eq(Statistics::Match.new(home_player_ids: %w[a c], away_player_ids: %w[b d],
                                                home_score: 10, away_score: 4))
    end

    it "queries MatchRegistered scoped to the league" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[MatchRegistered])
      expect(item.tags).to eq([ "league:league-1" ])
    end
  end

  describe ".for_league", :event_store do
    it "returns the league's matches oldest first" do
      EventStore.append([ match_registered, match_registered(match_id: "m-2", home_score: 3, away_score: 5) ])
      expect(described_class.for_league("league-1").map(&:home_score)).to eq([ 21, 3 ])
    end

    it "ignores matches from other leagues" do
      EventStore.append([ match_registered(league_id: "league-2") ])
      expect(described_class.for_league("league-1")).to eq([])
    end
  end
end
