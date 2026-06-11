require "rails_helper"

RSpec.describe Statistics::PlayerPage, :event_store do
  def league
    Statistics::LeagueConfig::Config.new(
      league_id: "league-1", account_id: "acc-1", name: "Foosball Spring",
      starting_points: 1000, stake_percentage: 10
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

  def register_users
    [ user_registered(user_id: "a", name: "Alice"), user_registered(user_id: "b", name: "Bob"),
      user_registered(user_id: "c", name: "Carol") ]
  end

  it "is nil when the league has no matches" do
    expect(described_class.find(league:, player_id: "a")).to be_nil
  end

  it "is nil for a player who never appeared in a league match" do
    EventStore.append(register_users +
      [ match_registered(match_id: "m-1", home: [ "a" ], away: [ "b" ], home_score: 21, away_score: 8) ])
    expect(described_class.find(league:, player_id: "c")).to be_nil
  end

  it "ignores the player's matches in other leagues" do
    EventStore.append(register_users +
      [ match_registered(match_id: "m-1", home: [ "a" ], away: [ "b" ],
                         home_score: 21, away_score: 8, league_id: "league-2") ])
    expect(described_class.find(league:, player_id: "a")).to be_nil
  end

  describe "an assembled page" do
    # Match 1: Alice beats Bob 21-8    -> Alice 1100, Bob 900
    # Match 2: Bob beats Carol 21-15   -> Bob 1000, Carol 900
    # Match 3: Alice beats Carol 21-18 -> Alice 1190, Carol 810
    before do
      EventStore.append(register_users + [
        match_registered(match_id: "m-1", home: [ "a" ], away: [ "b" ], home_score: 21, away_score: 8),
        match_registered(match_id: "m-2", home: [ "b" ], away: [ "c" ], home_score: 21, away_score: 15),
        match_registered(match_id: "m-3", home: [ "a" ], away: [ "c" ], home_score: 21, away_score: 18)
      ])
    end

    subject(:page) { described_class.find(league:, player_id: "a") }

    it "carries the player's id and display name" do
      expect(page).to have_attributes(player_id: "a", name: "Alice")
    end

    it "shows the current points, rank and matches played" do
      expect(page).to have_attributes(points: 1190, rank: 1, played: 2)
    end

    it "ranks every player, not just the requested one" do
      expect(described_class.find(league:, player_id: "b")).to have_attributes(points: 1000, rank: 2)
      expect(described_class.find(league:, player_id: "c")).to have_attributes(points: 810, rank: 3)
    end

    it "joins the form tokens with spaces, most recent first" do
      expect(page.form).to eq("W W")
      expect(described_class.find(league:, player_id: "c").form).to eq("L L")
    end

    it "lists head-to-head rows by most played, then name" do
      expect(page.head_to_head).to eq([
        Statistics::HeadToHead::Row.new(opponent: "Bob", played: 1, won: 1, lost: 0),
        Statistics::HeadToHead::Row.new(opponent: "Carol", played: 1, won: 1, lost: 0)
      ])
    end

    it "lists the match history newest first with the running balance" do
      expect(page.history).to eq([
        Statistics::MatchHistory::Row.new(line: "Alice beats Carol 21-18", points_after: 1190),
        Statistics::MatchHistory::Row.new(line: "Alice beats Bob 21-8", points_after: 1100)
      ])
    end
  end

  it "uses the league's scoring settings" do
    EventStore.append(register_users +
      [ match_registered(match_id: "m-1", home: [ "a" ], away: [ "b" ], home_score: 21, away_score: 8) ])
    page = described_class.find(league: league.with(starting_points: 1015, stake_percentage: 20),
                                player_id: "a")
    expect(page.points).to eq(1218)
  end

  it "falls back to the player id when no name is registered" do
    EventStore.append([ match_registered(match_id: "m-1", home: [ "ghost" ], away: [ "b" ],
                                         home_score: 21, away_score: 8) ])
    page = described_class.find(league:, player_id: "ghost")
    expect(page.name).to eq("ghost")
    expect(page.history.sole.line).to eq("ghost beats b 21-8")
  end
end
