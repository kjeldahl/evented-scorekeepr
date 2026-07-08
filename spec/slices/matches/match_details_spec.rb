require "rails_helper"

RSpec.describe Matches::MatchDetails do
  def match_registered(match_id: "m-1", league_id: "league-1", account_id: "acc-1",
                       home: %w[alice carol], away: %w[bob dave], home_score: 21, away_score: 8)
    DcbEventStore::Event.new(
      type: "MatchRegistered",
      data: { match_id:, league_id:, account_id:, home_player_ids: home, away_player_ids: away,
              home_score:, away_score:, registered_by_user_id: home.first },
      tags: [ "match:#{match_id}", "league:#{league_id}", "account:#{account_id}",
              *(home + away).map { |player| "player:#{player}" } ]
    )
  end

  def match_corrected(match_id: "m-1", league_id: "league-1", account_id: "acc-1",
                      home_score: 21, away_score: 18)
    DcbEventStore::Event.new(
      type: "MatchResultCorrected",
      data: { match_id:, league_id:, account_id:, home_score:, away_score:, corrected_by_user_id: "bob" },
      tags: [ "match:#{match_id}", "league:#{league_id}", "account:#{account_id}" ]
    )
  end

  def match_deleted(match_id: "m-1", league_id: "league-1", account_id: "acc-1")
    DcbEventStore::Event.new(
      type: "MatchDeleted",
      data: { match_id:, league_id:, account_id:, deleted_by_user_id: "bob" },
      tags: [ "match:#{match_id}", "league:#{league_id}", "account:#{account_id}" ]
    )
  end

  describe ".projection (pure fold)" do
    subject(:projection) { described_class.projection(match_id: "m-1") }

    it "is nil for a match that was never registered" do
      expect(projection.fold([])).to be_nil
    end

    it "stays nil when a delete arrives before any registration" do
      expect(projection.fold([ match_deleted ])).to be_nil
    end

    it "marks the match deleted once MatchDeleted lands" do
      expect(projection.fold([ match_registered, match_deleted ])).to be_deleted
    end

    it "marks a corrected match deleted once MatchDeleted lands" do
      expect(projection.fold([ match_registered, match_corrected, match_deleted ])).to be_deleted
    end

    it "folds MatchRegistered into the sides, league, account and score, not deleted" do
      details = projection.fold([ match_registered ])
      expect(details).to eq(Matches::MatchDetails::Details.new(
        match_id: "m-1", league_id: "league-1", account_id: "acc-1",
        home_player_ids: %w[alice carol], away_player_ids: %w[bob dave], home_score: 21, away_score: 8,
        deleted: false
      ))
    end

    it "applies a later correction to the score, leaving the sides fixed" do
      details = projection.fold([ match_registered, match_corrected(home_score: 21, away_score: 18) ])
      expect(details.home_score).to eq(21)
      expect(details.away_score).to eq(18)
      expect(details.home_player_ids).to eq(%w[alice carol])
    end

    it "ignores a correction that arrives before any registration" do
      expect(projection.fold([ match_corrected ])).to be_nil
    end

    it "queries the match's own events by the match tag" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[MatchRegistered MatchResultCorrected MatchDeleted])
      expect(item.tags).to eq([ "match:m-1" ])
    end
  end

  describe "Details#players" do
    it "lists the home side first, then the away side" do
      details = described_class.projection(match_id: "m-1").fold([ match_registered ])
      expect(details.players).to eq(%w[alice carol bob dave])
    end
  end

  describe ".find", :event_store do
    it "reads the match from the store, correction applied" do
      EventStore.append([ match_registered(home_score: 21, away_score: 8), match_corrected(home_score: 15, away_score: 21) ])
      details = described_class.find(match_id: "m-1")
      expect([ details.home_score, details.away_score ]).to eq([ 15, 21 ])
    end

    it "is nil for an unknown match" do
      expect(described_class.find(match_id: "missing")).to be_nil
    end

    it "is nil once the match is deleted" do
      EventStore.append([ match_registered, match_deleted ])
      expect(described_class.find(match_id: "m-1")).to be_nil
    end
  end
end
