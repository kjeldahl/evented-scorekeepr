require "rails_helper"

RSpec.describe Scoreboards::LeagueOverview do
  def league_created(league_id: "league-1", account_id: "acc-1", starting_points: 1015, stake_percentage: 20)
    DcbEventStore::Event.new(
      type: "LeagueCreated",
      data: { league_id:, account_id:, name: "Foosball Spring", game_type: "Foosball",
              starting_points:, stake_percentage: },
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

    it "folds LeagueCreated into an open summary with the league's settings" do
      summary = projection.fold([ league_created ])
      expect(summary).to have_attributes(league_id: "league-1", account_id: "acc-1",
                                         name: "Foosball Spring", game_type: "Foosball",
                                         starting_points: 1015, stake_percentage: 20)
      expect(summary).to be_open
      expect(summary).not_to be_closed
    end

    it "folds LeagueClosed into a closed summary that keeps the settings" do
      summary = projection.fold([ league_created, league_closed ])
      expect(summary).to be_closed
      expect(summary).not_to be_open
      expect(summary.starting_points).to eq(1015)
    end

    it "stays nil when only a close event is folded (no creation seen)" do
      expect(projection.fold([ league_closed ])).to be_nil
    end

    it "queries the lifecycle events scoped to both league and account (tenancy)" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[LeagueCreated LeagueClosed])
      expect(item.tags).to contain_exactly("league:league-1", "account:acc-1")
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
