require "rails_helper"

RSpec.describe Matches::League do
  def league_created(league_id: "league-1", account_id: "acc-1", name: "Foosball Spring")
    DcbEventStore::Event.new(
      type: "LeagueCreated",
      data: { league_id:, account_id:, name:, game_type: "Foosball",
              starting_points: 1000, stake_percentage: 10 },
      tags: [ "league:#{league_id}", "account:#{account_id}" ]
    )
  end

  def league_renamed(league_id: "league-1", account_id: "acc-1", name: "Foosball Summer")
    DcbEventStore::Event.new(
      type: "LeagueRenamed",
      data: { league_id:, account_id:, name: },
      tags: [ "league:#{league_id}", "account:#{account_id}" ]
    )
  end

  def league_closed(league_id: "league-1", account_id: "acc-1")
    DcbEventStore::Event.new(
      type: "LeagueClosed",
      data: { league_id:, account_id: },
      tags: [ "league:#{league_id}", "account:#{account_id}" ]
    )
  end

  describe ".projection" do
    subject(:projection) { described_class.projection(league_id: "league-1", account_id: "acc-1") }

    it "starts with no league" do
      expect(projection.initial_state).to be_nil
    end

    it "folds LeagueCreated into an open league with its name" do
      summary = projection.fold([ league_created ])
      expect(summary.name).to eq("Foosball Spring")
      expect(summary).to be_open
    end

    it "folds LeagueClosed into a closed league" do
      summary = projection.fold([ league_created, league_closed ])
      expect(summary).to be_closed
      expect(summary.name).to eq("Foosball Spring")
    end

    it "carries the new name after a LeagueRenamed event" do
      summary = projection.fold([ league_created, league_renamed ])
      expect(summary.name).to eq("Foosball Summer")
      expect(summary).to be_open
    end

    it "stays nil when only a close or rename event is folded (no creation seen)" do
      expect(projection.fold([ league_closed ])).to be_nil
      expect(projection.fold([ league_renamed ])).to be_nil
    end

    it "queries the lifecycle events scoped to both league and account (tenancy)" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[LeagueCreated LeagueRenamed LeagueClosed])
      expect(item.tags).to contain_exactly("league:league-1", "account:acc-1")
    end

    it "reads game_type from LeagueCreated" do
      summary = projection.fold([ league_created ])
      expect(summary.game_type).to eq("Foosball")
    end

    it "reads match_type from LeagueCreated (defaults to 'match')" do
      summary = projection.fold([ league_created ])
      expect(summary.match_type).to eq("match")
    end

    it "reads match_type when explicitly set" do
      event = DcbEventStore::Event.new(
        type: "LeagueCreated",
        data: { league_id: "league-1", account_id: "acc-1", name: "Multiplayer",
                game_type: "Golf", match_type: "multiplayer" },
        tags: [ "league:league-1", "account:acc-1" ]
      )
      summary = projection.fold([ event ])
      expect(summary.match_type).to eq("multiplayer")
      expect(summary).to be_multiplayer_league
      expect(summary).not_to be_match_league
    end

    it "defaults match_type to 'match' when the event has no match_type key" do
      event = DcbEventStore::Event.new(
        type: "LeagueCreated",
        data: { league_id: "league-1", account_id: "acc-1", name: "Legacy",
                game_type: "Foosball", starting_points: 1000, stake_percentage: 10 },
        tags: [ "league:league-1", "account:acc-1" ]
      )
      summary = projection.fold([ event ])
      expect(summary.match_type).to eq("match")
    end
  end

  describe ".find", :event_store do
    it "returns nil for an unknown league" do
      expect(described_class.find(league_id: "league-1", account_id: "acc-1")).to be_nil
    end

    it "returns the open league summary after creation" do
      EventStore.append([ league_created ])
      expect(described_class.find(league_id: "league-1", account_id: "acc-1")).to be_open
    end

    it "does not find a league through a different account (tenancy)" do
      EventStore.append([ league_created(account_id: "acc-2") ])
      expect(described_class.find(league_id: "league-1", account_id: "acc-1")).to be_nil
    end
  end
end
