require "rails_helper"

RSpec.describe Leagues::LeagueState do
  subject(:projection) { described_class.projection(league_id: "league-1", account_id: "acc-1") }

  def created
    Leagues::Events.league_created(
      league_id: "league-1", account_id: "acc-1", name: "Foosball Spring",
      game_type: "Foosball", starting_points: 1000, stake_percentage: 10
    )
  end

  def closed
    Leagues::Events.league_closed(league_id: "league-1", account_id: "acc-1")
  end

  it "starts with no league" do
    expect(projection.initial_state).to eq(:none)
  end

  it "is open once a LeagueCreated event is folded" do
    expect(projection.fold([ created ])).to eq(:open)
  end

  it "is closed once a LeagueClosed event is folded" do
    expect(projection.fold([ created, closed ])).to eq(:closed)
  end

  it "queries the lifecycle events scoped to the league and its account" do
    item = projection.query.items.sole
    expect(item.event_types).to eq(%w[LeagueCreated LeagueClosed])
    expect(item.tags).to contain_exactly("league:league-1", "account:acc-1")
  end
end
