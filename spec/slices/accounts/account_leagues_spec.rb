require "rails_helper"

# The accounts slice folds the leagues slice's events (the cross-slice
# contract per docs/DOMAIN.md), so the fixtures build raw events with the
# documented type/data/tags.
RSpec.describe Accounts::AccountLeagues do
  def league_created(league_id:, name:, account_id: "acc-1")
    DcbEventStore::Event.new(
      type: "LeagueCreated",
      data: { league_id:, account_id:, name:, game_type: "Foosball", starting_points: 1000, stake_percentage: 10 },
      tags: [ "league:#{league_id}", "account:#{account_id}" ]
    )
  end

  def league_closed(league_id:, account_id: "acc-1")
    DcbEventStore::Event.new(
      type: "LeagueClosed",
      data: { league_id:, account_id: },
      tags: [ "league:#{league_id}", "account:#{account_id}" ]
    )
  end

  describe ".projection" do
    subject(:projection) { described_class.projection("acc-1") }

    it "starts with no leagues" do
      expect(projection.initial_state).to eq({})
    end

    it "lists a created league as open" do
      state = projection.fold([ league_created(league_id: "lg-1", name: "Office Foosball") ])
      league = state.fetch("lg-1")
      expect(league.name).to eq("Office Foosball")
      expect(league).to be_open
    end

    it "keeps earlier leagues when another league is created" do
      state = projection.fold([ league_created(league_id: "lg-1", name: "Office Foosball"),
                                league_created(league_id: "lg-2", name: "Office Darts") ])
      expect(state.keys).to eq(%w[lg-1 lg-2])
    end

    it "marks a closed league as not open" do
      events = [ league_created(league_id: "lg-1", name: "Office Foosball"), league_closed(league_id: "lg-1") ]
      expect(projection.fold(events).fetch("lg-1")).not_to be_open
    end

    it "ignores a close for an unknown league" do
      expect(projection.fold([ league_closed(league_id: "lg-9") ])).to eq({})
    end

    it "queries league lifecycle events tagged with the account" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[LeagueCreated LeagueClosed])
      expect(item.tags).to eq([ "account:acc-1" ])
    end
  end

  describe ".for_account", :event_store do
    it "lists the account's leagues, not other accounts'" do
      EventStore.append([
        league_created(league_id: "lg-1", name: "Office Foosball"),
        league_created(league_id: "lg-2", name: "Family Foosball", account_id: "acc-2")
      ])
      leagues = described_class.for_account("acc-1")
      expect(leagues.map(&:league_id)).to eq([ "lg-1" ])
    end
  end
end
