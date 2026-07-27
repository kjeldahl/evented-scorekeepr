require "rails_helper"

RSpec.describe Scoreboards::Scoreboard, :event_store do
  def league(match_type: "match")
    Scoreboards::LeagueOverview::Summary.new(
      league_id: "league-1", account_id: "acc-1", name: "Foosball Spring", game_type: "Foosball",
      starting_points: 1000, stake_percentage: 10, status: :open, match_type:
    )
  end

  def user_registered(user_id:, name:)
    DcbEventStore::Event.new(
      type: "UserRegistered",
      data: { user_id:, name:, email: "#{user_id}@example.com", password_digest: "x" },
      tags: [ "user:#{user_id}", "user_email:#{user_id}@example.com" ]
    )
  end

  def match_registered(match_id:, home:, away:, home_score:, away_score:, league_id: "league-1")
    DcbEventStore::Event.new(
      type: "MatchRegistered",
      data: { match_id:, league_id:, account_id: "acc-1", home_player_ids: home,
              away_player_ids: away, home_score:, away_score:, registered_by_user_id: home.first },
      tags: [ "match:#{match_id}", "league:#{league_id}", "account:acc-1",
              *(home + away).map { |player| "player:#{player}" } ]
    )
  end

  it "has no rows before any match" do
    expect(described_class.rows(league)).to eq([])
  end

  it "folds the league's matches into ranked rows with display names" do
    EventStore.append([
      user_registered(user_id: "a", name: "Alice"), user_registered(user_id: "b", name: "Bob"),
      match_registered(match_id: "m-1", home: [ "a" ], away: [ "b" ], home_score: 21, away_score: 8)
    ])
    rows = described_class.rows(league)
    expect(rows.map { |row| [ row.rank, row.name, row.points, row.streak ] })
      .to eq([ [ 1, "Alice", 1100, "W1" ], [ 2, "Bob", 900, "L1" ] ])
  end

  it "uses the league's scoring settings" do
    EventStore.append([
      user_registered(user_id: "a", name: "Alice"), user_registered(user_id: "b", name: "Bob"),
      match_registered(match_id: "m-1", home: [ "a" ], away: [ "b" ], home_score: 21, away_score: 8)
    ])
    rows = described_class.rows(league.with(starting_points: 1015, stake_percentage: 10, match_type: "match"))
    expect(rows.map(&:points)).to eq([ 1116, 914 ])
  end

  it "ignores matches from other leagues" do
    EventStore.append([
      user_registered(user_id: "a", name: "Alice"), user_registered(user_id: "b", name: "Bob"),
      match_registered(match_id: "m-1", home: [ "a" ], away: [ "b" ],
                       home_score: 21, away_score: 8, league_id: "league-2")
    ])
    expect(described_class.rows(league)).to eq([])
  end
end
