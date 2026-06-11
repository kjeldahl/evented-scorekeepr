require "rails_helper"

RSpec.describe Leagues::Events do
  describe ".league_created" do
    subject(:event) do
      described_class.league_created(
        league_id: "league-1", account_id: "acc-1", name: "Foosball Spring",
        game_type: "Foosball", starting_points: 1000, stake_percentage: 10
      )
    end

    it "has the LeagueCreated type" do
      expect(event.type).to eq("LeagueCreated")
    end

    it "carries the league settings as data" do
      expect(event.data).to eq(
        league_id: "league-1", account_id: "acc-1", name: "Foosball Spring",
        game_type: "Foosball", starting_points: 1000, stake_percentage: 10
      )
    end

    it "is tagged with the league and the account" do
      expect(event.tags).to contain_exactly("league:league-1", "account:acc-1")
    end
  end

  describe ".league_renamed" do
    subject(:event) do
      described_class.league_renamed(league_id: "league-1", account_id: "acc-1", name: "Foosball Summer")
    end

    it "has the LeagueRenamed type" do
      expect(event.type).to eq("LeagueRenamed")
    end

    it "carries league_id, account_id and the new name as data" do
      expect(event.data).to eq(league_id: "league-1", account_id: "acc-1", name: "Foosball Summer")
    end

    it "is tagged with the league and the account" do
      expect(event.tags).to contain_exactly("league:league-1", "account:acc-1")
    end
  end

  describe ".league_closed" do
    subject(:event) { described_class.league_closed(league_id: "league-1", account_id: "acc-1") }

    it "has the LeagueClosed type" do
      expect(event.type).to eq("LeagueClosed")
    end

    it "carries league_id and account_id as data" do
      expect(event.data).to eq(league_id: "league-1", account_id: "acc-1")
    end

    it "is tagged with the league and the account" do
      expect(event.tags).to contain_exactly("league:league-1", "account:acc-1")
    end
  end
end
