require "rails_helper"

RSpec.describe Scoreboards::LeagueMatches do
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

  def match_corrected(match_id: "m-1", league_id: "league-1", home_score: 21, away_score: 18)
    DcbEventStore::Event.new(
      type: "MatchResultCorrected",
      data: { match_id:, league_id:, account_id: "acc-1", home_score:, away_score:, corrected_by_user_id: "b" },
      tags: [ "match:#{match_id}", "league:#{league_id}", "account:acc-1" ]
    )
  end

  def match_deleted(match_id: "m-1", league_id: "league-1")
    DcbEventStore::Event.new(
      type: "MatchDeleted",
      data: { match_id:, league_id:, account_id: "acc-1", deleted_by_user_id: "b" },
      tags: [ "match:#{match_id}", "league:#{league_id}", "account:acc-1" ]
    )
  end

  def multiplayer_registered(match_id: "mp-1", league_id: "league-1", players: %w[a b], scores: { a: 10, b: 5 })
    DcbEventStore::Event.new(
      type: "MultiplayerMatchRegistered",
      data: { match_id:, league_id:, account_id: "acc-1", player_ids: players, player_scores: scores,
              registered_by_user_id: players.first },
      tags: [ "match:#{match_id}", "league:#{league_id}", "account:acc-1",
              *players.map { |player| "player:#{player}" } ]
    )
  end

  def multiplayer_corrected(match_id: "mp-1", league_id: "league-1", scores: { a: 3, b: 9 })
    DcbEventStore::Event.new(
      type: "MultiplayerMatchResultCorrected",
      data: { match_id:, league_id:, account_id: "acc-1", player_scores: scores, corrected_by_user_id: "a" },
      tags: [ "match:#{match_id}", "league:#{league_id}", "account:acc-1" ]
    )
  end

  def multiplayer_deleted(match_id: "mp-1", league_id: "league-1")
    DcbEventStore::Event.new(
      type: "MultiplayerMatchDeleted",
      data: { match_id:, league_id:, account_id: "acc-1", deleted_by_user_id: "a" },
      tags: [ "match:#{match_id}", "league:#{league_id}", "account:acc-1" ]
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

    it "carries the id, sides and scores onto the Match value" do
      match = projection.fold([ match_registered(match_id: "m-1", home: %w[a c], away: %w[b d], home_score: 10, away_score: 4) ]).sole
      expect(match).to eq(Scoreboards::Match.new(match_id: "m-1", home_player_ids: %w[a c], away_player_ids: %w[b d],
                                                 home_score: 10, away_score: 4))
    end

    it "applies a correction to its match's score, keeping league order" do
      matches = projection.fold([
        match_registered(match_id: "m-1", home_score: 21, away_score: 8),
        match_registered(match_id: "m-2", home_score: 21, away_score: 15),
        match_corrected(match_id: "m-1", home_score: 17, away_score: 18)
      ])
      expect(matches.map { |match| [ match.match_id, match.home_score, match.away_score ] })
        .to eq([ [ "m-1", 17, 18 ], [ "m-2", 21, 15 ] ])
    end

    it "leaves other matches untouched by a correction" do
      matches = projection.fold([
        match_registered(match_id: "m-1"),
        match_corrected(match_id: "m-2", home_score: 1, away_score: 2)
      ])
      expect(matches.sole.home_score).to eq(21)
    end

    it "drops a deleted match, keeping the others in league order" do
      matches = projection.fold([
        match_registered(match_id: "m-1"),
        match_registered(match_id: "m-2", home_score: 3, away_score: 5),
        match_deleted(match_id: "m-1")
      ])
      expect(matches.map(&:match_id)).to eq([ "m-2" ])
    end

    it "leaves other matches untouched by a deletion" do
      matches = projection.fold([
        match_registered(match_id: "m-1"),
        match_deleted(match_id: "m-2")
      ])
      expect(matches.sole.match_id).to eq("m-1")
    end

    it "carries the id, players and scores onto the MultiplayerMatch value" do
      match = projection.fold([ multiplayer_registered(match_id: "mp-1", players: %w[a b c],
                                                       scores: { a: 10, b: 5, c: 3 }) ]).sole
      expect(match).to eq(Scoreboards::MultiplayerMatch.new(match_id: "mp-1", player_ids: %w[a b c],
                                                            player_scores: { a: 10, b: 5, c: 3 }))
    end

    it "keeps both kinds of match in one league order" do
      matches = projection.fold([
        match_registered(match_id: "m-1"),
        multiplayer_registered(match_id: "mp-1"),
        match_registered(match_id: "m-2")
      ])
      expect(matches.map(&:match_id)).to eq(%w[m-1 mp-1 m-2])
    end

    it "applies a multiplayer correction to its match's scores, keeping league order" do
      matches = projection.fold([
        multiplayer_registered(match_id: "mp-1"),
        multiplayer_registered(match_id: "mp-2", scores: { a: 1, b: 2 }),
        multiplayer_corrected(match_id: "mp-1", scores: { a: 3, b: 9 })
      ])
      expect(matches.map { |match| [ match.match_id, match.player_scores ] })
        .to eq([ [ "mp-1", { a: 3, b: 9 } ], [ "mp-2", { a: 1, b: 2 } ] ])
    end

    it "leaves other multiplayer matches untouched by a correction" do
      matches = projection.fold([
        multiplayer_registered(match_id: "mp-1"),
        multiplayer_corrected(match_id: "mp-2", scores: { a: 3, b: 9 })
      ])
      expect(matches.sole.player_scores).to eq({ a: 10, b: 5 })
    end

    it "never applies a multiplayer correction to a head-to-head match with the same id" do
      matches = projection.fold([
        match_registered(match_id: "same-id", home_score: 21, away_score: 8),
        multiplayer_corrected(match_id: "same-id", scores: { a: 3, b: 9 })
      ])
      expect(matches.sole).to have_attributes(home_score: 21, away_score: 8)
    end

    it "never applies a head-to-head correction to a multiplayer match with the same id" do
      matches = projection.fold([
        multiplayer_registered(match_id: "same-id"),
        match_corrected(match_id: "same-id", home_score: 1, away_score: 2)
      ])
      expect(matches.sole.player_scores).to eq({ a: 10, b: 5 })
    end

    it "drops a deleted multiplayer match, keeping the others in league order" do
      matches = projection.fold([
        multiplayer_registered(match_id: "mp-1"),
        multiplayer_registered(match_id: "mp-2"),
        multiplayer_deleted(match_id: "mp-1")
      ])
      expect(matches.map(&:match_id)).to eq([ "mp-2" ])
    end

    it "never drops a head-to-head match on a multiplayer deletion with the same id" do
      matches = projection.fold([
        match_registered(match_id: "same-id"),
        multiplayer_deleted(match_id: "same-id")
      ])
      expect(matches.sole.match_id).to eq("same-id")
    end

    it "never drops a multiplayer match on a head-to-head deletion with the same id" do
      matches = projection.fold([
        multiplayer_registered(match_id: "same-id"),
        match_deleted(match_id: "same-id")
      ])
      expect(matches.sole.match_id).to eq("same-id")
    end

    it "queries all six match event types scoped to the league" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[MatchRegistered MatchResultCorrected MatchDeleted MultiplayerMatchRegistered MultiplayerMatchResultCorrected MultiplayerMatchDeleted])
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
