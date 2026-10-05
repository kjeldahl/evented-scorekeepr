require "rails_helper"

RSpec.describe Leagues::League do
  def created(league_id: "league-1", starting_points: 1000, stake_percentage: 10, match_type: "match")
    Leagues::Events.league_created(
      league_id:, account_id: "acc-1", name: "Foosball Spring",
      game_type: "Foosball", starting_points:, stake_percentage:, match_type:
    )
  end

  # A LeagueCreated appended before leagues had a match type.
  def created_without_match_type
    event = created
    DcbEventStore::Event.new(type: event.type, data: event.data.except(:match_type), tags: event.tags)
  end

  def renamed(league_id: "league-1", name: "Foosball Summer")
    Leagues::Events.league_renamed(league_id:, account_id: "acc-1", name:)
  end

  def closed(league_id: "league-1")
    Leagues::Events.league_closed(league_id:, account_id: "acc-1")
  end

  describe ".projection" do
    subject(:projection) { described_class.projection("league-1") }

    it "starts with no league" do
      expect(projection.initial_state).to be_nil
    end

    it "folds LeagueCreated into an open summary with the league settings" do
      summary = projection.fold([ created(starting_points: 1500, stake_percentage: 20) ])
      expect(summary).to have_attributes(
        id: "league-1", account_id: "acc-1", name: "Foosball Spring", game_type: "Foosball",
        starting_points: 1500, stake_percentage: 20, status: :open
      )
    end

    it "folds a multiplayer LeagueCreated into a multiplayer league" do
      summary = projection.fold([ created(match_type: "multiplayer") ])
      expect(summary).to have_attributes(match_type: "multiplayer", multiplayer_league?: true, match_league?: false)
    end

    it "folds a match LeagueCreated into a match league" do
      summary = projection.fold([ created(match_type: "match") ])
      expect(summary).to have_attributes(match_type: "match", match_league?: true, multiplayer_league?: false)
    end

    it "treats a LeagueCreated without a match type as a match league" do
      expect(projection.fold([ created_without_match_type ]).match_type).to eq("match")
    end

    it "is open and not closed after creation" do
      summary = projection.fold([ created ])
      expect(summary.open?).to be(true)
      expect(summary.closed?).to be(false)
    end

    it "is closed and no longer open after a LeagueClosed event" do
      summary = projection.fold([ created, closed ])
      expect(summary.closed?).to be(true)
      expect(summary.open?).to be(false)
    end

    it "carries the new name after a LeagueRenamed event" do
      summary = projection.fold([ created, renamed(name: "Foosball Summer") ])
      expect(summary.name).to eq("Foosball Summer")
      expect(summary.open?).to be(true)
    end

    it "stays absent when a stray LeagueClosed or LeagueRenamed arrives without a creation" do
      expect(projection.fold([ closed ])).to be_nil
      expect(projection.fold([ renamed ])).to be_nil
    end

    it "queries the lifecycle events tagged with the league" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[LeagueCreated LeagueRenamed LeagueClosed])
      expect(item.tags).to contain_exactly("league:league-1")
    end
  end

  describe ".find", :event_store do
    it "returns nil when no such league exists" do
      expect(described_class.find("league-1")).to be_nil
    end

    it "returns the summary for the requested league only" do
      EventStore.append([ created, created(league_id: "league-2"), closed(league_id: "league-2") ])
      expect(described_class.find("league-1")).to have_attributes(id: "league-1", status: :open)
    end
  end
end
