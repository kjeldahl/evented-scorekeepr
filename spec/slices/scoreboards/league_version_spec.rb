require "rails_helper"

RSpec.describe Scoreboards::LeagueVersion do
  def event(type, league_id: "league-1")
    DcbEventStore::Event.new(type:, data: { league_id: }, tags: [ "league:#{league_id}" ])
  end

  describe ".projection (pure fold)" do
    subject(:projection) { described_class.projection(league_id: "league-1") }

    it "starts at zero" do
      expect(projection.fold([])).to eq(0)
    end

    it "counts a LeagueCreated event" do
      expect(projection.fold([ event("LeagueCreated") ])).to eq(1)
    end

    it "counts a LeagueRenamed event" do
      expect(projection.fold([ event("LeagueRenamed") ])).to eq(1)
    end

    it "counts a LeagueClosed event" do
      expect(projection.fold([ event("LeagueClosed") ])).to eq(1)
    end

    it "counts a MatchRegistered event" do
      expect(projection.fold([ event("MatchRegistered") ])).to eq(1)
    end

    it "counts a MatchResultCorrected event" do
      expect(projection.fold([ event("MatchResultCorrected") ])).to eq(1)
    end

    it "adds one per event across the five types" do
      events = [ event("LeagueCreated"), event("LeagueRenamed"), event("LeagueClosed"),
                 event("MatchRegistered"), event("MatchResultCorrected") ]
      expect(projection.fold(events)).to eq(5)
    end

    it "ignores event types outside the versioned five" do
      expect(projection.fold([ event("PlayerInvited") ])).to eq(0)
    end

    it "queries exactly the five versioned event types scoped to the league's tag" do
      expect(projection.query.items).to contain_exactly(
        DcbEventStore::QueryItem.new(
          event_types: %w[LeagueCreated LeagueRenamed LeagueClosed MatchRegistered MatchResultCorrected],
          tags: [ "league:league-1" ]
        )
      )
    end
  end

  describe ".version", :event_store do
    it "is zero for a league without events" do
      expect(described_class.version(league_id: "league-1")).to eq(0)
    end

    it "counts only the named league's events" do
      EventStore.append([
        event("LeagueCreated"), event("MatchRegistered"),
        event("LeagueCreated", league_id: "league-2")
      ])
      expect(described_class.version(league_id: "league-1")).to eq(2)
    end

    it "does not count other event types tagged with the league" do
      EventStore.append([ event("LeagueCreated"), event("PlayerInvited") ])
      expect(described_class.version(league_id: "league-1")).to eq(1)
    end

    it "is strictly greater after a match is registered" do
      EventStore.append(event("LeagueCreated"))
      before = described_class.version(league_id: "league-1")
      EventStore.append(event("MatchRegistered"))
      expect(described_class.version(league_id: "league-1")).to be > before
    end
  end
end
