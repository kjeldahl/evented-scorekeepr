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

  def multiplayer_registered(match_id:, players:, scores:, league_id: "league-1")
    DcbEventStore::Event.new(
      type: "MultiplayerMatchRegistered",
      data: { match_id:, league_id:, account_id: "acc-1", player_ids: players,
              player_scores: scores, registered_by_user_id: players.first },
      tags: [ "match:#{match_id}", "league:#{league_id}", "account:acc-1",
              *players.map { |player| "player:#{player}" } ]
    )
  end

  # The facade passes the league's mode and game type down to the standings,
  # so a multiplayer league is scored by the multiplayer engine and ranked in
  # its game type's direction.
  it "scores a multiplayer league with the multiplayer engine" do
    EventStore.append([
      user_registered(user_id: "a", name: "Alice"), user_registered(user_id: "b", name: "Bob"),
      multiplayer_registered(match_id: "mp-1", players: %w[a b], scores: { a: 21, b: 8 })
    ])
    rows = described_class.rows(league(match_type: "multiplayer"))
    expect(rows.map { |row| [ row.name, row.points, row.wins ] })
      .to eq([ [ "Alice", 1100, 1 ], [ "Bob", 900, 0 ] ])
  end

  it "ranks a multiplayer league by its game type's direction" do
    EventStore.append([
      user_registered(user_id: "a", name: "Alice"), user_registered(user_id: "b", name: "Bob"),
      multiplayer_registered(match_id: "mp-1", players: %w[a b], scores: { a: 21, b: 8 })
    ])
    rows = described_class.rows(league(match_type: "multiplayer").with(game_type: "Golf"))
    expect(rows.map { |row| [ row.name, row.points, row.wins ] })
      .to eq([ [ "Bob", 1100, 1 ], [ "Alice", 900, 0 ] ])
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
