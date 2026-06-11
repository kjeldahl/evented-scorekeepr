require "rails_helper"

RSpec.describe Statistics::LeagueConfig do
  def league_created(league_id: "league-1", account_id: "acc-1", starting_points: 1015, stake_percentage: 20)
    DcbEventStore::Event.new(
      type: "LeagueCreated",
      data: { league_id:, account_id:, name: "Foosball Spring", game_type: "Foosball",
              starting_points:, stake_percentage: },
      tags: [ "league:#{league_id}", "account:#{account_id}" ]
    )
  end

  describe ".projection" do
    subject(:projection) { described_class.projection(league_id: "league-1", account_id: "acc-1") }

    it "starts with no league" do
      expect(projection.initial_state).to be_nil
    end

    it "folds LeagueCreated into the league's name and scoring configuration" do
      config = projection.fold([ league_created ])
      expect(config).to eq(described_class::Config.new(
        league_id: "league-1", account_id: "acc-1", name: "Foosball Spring",
        starting_points: 1015, stake_percentage: 20
      ))
    end

    it "carries the new name after a LeagueRenamed event, keeping the settings" do
      renamed = DcbEventStore::Event.new(
        type: "LeagueRenamed",
        data: { league_id: "league-1", account_id: "acc-1", name: "Foosball Summer" },
        tags: [ "league:league-1", "account:acc-1" ]
      )
      config = projection.fold([ league_created, renamed ])
      expect(config.name).to eq("Foosball Summer")
      expect(config.starting_points).to eq(1015)
    end

    it "stays nil when a rename arrives without a creation" do
      renamed = DcbEventStore::Event.new(
        type: "LeagueRenamed",
        data: { league_id: "league-1", account_id: "acc-1", name: "Ghost" },
        tags: [ "league:league-1", "account:acc-1" ]
      )
      expect(projection.fold([ renamed ])).to be_nil
    end

    it "queries the league configuration events scoped to both league and account (tenancy)" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[LeagueCreated LeagueRenamed])
      expect(item.tags).to contain_exactly("league:league-1", "account:acc-1")
    end
  end

  describe ".find", :event_store do
    it "returns nil for an unknown league" do
      expect(described_class.find(league_id: "league-1", account_id: "acc-1")).to be_nil
    end

    it "returns the league's configuration after creation" do
      EventStore.append([ league_created ])
      config = described_class.find(league_id: "league-1", account_id: "acc-1")
      expect(config).to have_attributes(name: "Foosball Spring", starting_points: 1015, stake_percentage: 20)
    end

    it "does not find a league through a different account (tenancy)" do
      EventStore.append([ league_created(account_id: "acc-2") ])
      expect(described_class.find(league_id: "league-1", account_id: "acc-1")).to be_nil
    end
  end
end
