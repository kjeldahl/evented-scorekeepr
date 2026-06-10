require "rails_helper"

RSpec.describe Leagues::League do
  def created(league_id: "league-1", starting_points: 1000, stake_percentage: 10)
    Leagues::Events.league_created(
      league_id:, account_id: "acc-1", name: "Foosball Spring",
      game_type: "Foosball", starting_points:, stake_percentage:
    )
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

    it "stays absent when a stray LeagueClosed arrives without a creation" do
      expect(projection.fold([ closed ])).to be_nil
    end

    it "queries the lifecycle events tagged with the league" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[LeagueCreated LeagueClosed])
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
