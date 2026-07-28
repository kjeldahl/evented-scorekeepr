require "rails_helper"

RSpec.describe Matches::DeleteMatch do
  # The match, league lifecycle and participation are folded from events, so
  # the spec appends raw LeagueCreated / LeagueClosed / MatchRegistered givens.
  def create_league(league_id: "league-1", account_id: "acc-1")
    EventStore.append([ DcbEventStore::Event.new(
      type: "LeagueCreated",
      data: { league_id:, account_id:, name: "Foosball Spring", game_type: "Foosball",
              starting_points: 1000, stake_percentage: 10 },
      tags: [ "league:#{league_id}", "account:#{account_id}" ]
    ) ])
  end

  def close_league(league_id: "league-1", account_id: "acc-1")
    EventStore.append([ DcbEventStore::Event.new(
      type: "LeagueClosed", data: { league_id:, account_id: },
      tags: [ "league:#{league_id}", "account:#{account_id}" ]
    ) ])
  end

  def register(match_id: "m-1", league_id: "league-1", account_id: "acc-1",
               home: [ "alice" ], away: [ "bob" ], home_score: 21, away_score: 8)
    EventStore.append([ DcbEventStore::Event.new(
      type: "MatchRegistered",
      data: { match_id:, league_id:, account_id:, home_player_ids: home, away_player_ids: away,
              home_score:, away_score:, registered_by_user_id: home.first },
      tags: [ "match:#{match_id}", "league:#{league_id}", "account:#{account_id}",
              *(home + away).map { |player| "player:#{player}" } ]
    ) ])
  end

  def register_multiplayer(match_id: "mp-1", league_id: "league-1", account_id: "acc-1",
                           player_ids: %w[alice bob carol],
                           player_scores: { "alice" => 10, "bob" => 5, "carol" => 3 })
    EventStore.append([ DcbEventStore::Event.new(
      type: "MultiplayerMatchRegistered",
      data: { match_id:, league_id:, account_id:, player_ids:, player_scores:,
              registered_by_user_id: player_ids.first },
      tags: [ "match:#{match_id}", "league:#{league_id}", "account:#{account_id}",
              *player_ids.map { |player| "player:#{player}" } ]
    ) ])
    match_id
  end

  def call(match_id: "m-1", league_id: "league-1", account_id: "acc-1", user_id: "bob")
    described_class.call(match_id:, league_id:, account_id:, user_id:)
  end

  def deletions
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[MatchDeleted]) ])
    )
  end

  def multiplayer_deletions
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[MultiplayerMatchDeleted]) ])
    )
  end

  before do
    create_league
    register
  end

  describe "authorisation", :event_store do
    it "rejects a deleter who did not play in the match" do
      expect(call(user_id: "carol")).to eq(Result.failure("only players in the match can delete it"))
    end

    it "lets a losing player who did not register the match delete it" do
      expect(call(user_id: "bob")).to be_success
    end

    it "lets any of the four players of a 2v2 delete it" do
      register(match_id: "m-2", home: %w[alice carol], away: %w[bob dave], home_score: 10, away_score: 4)
      expect(call(match_id: "m-2", user_id: "dave")).to be_success
    end

    it "appends nothing when the deleter did not play" do
      call(user_id: "carol")
      expect(deletions).to be_empty
    end
  end

  describe "match lookup", :event_store do
    it "rejects an unknown match" do
      expect(call(match_id: "missing")).to eq(Result.failure("the match was not found"))
    end

    it "rejects a match reached through a different league (tenancy)" do
      expect(call(league_id: "league-2")).to eq(Result.failure("the match was not found"))
    end

    it "rejects a match reached through a different account (tenancy)" do
      expect(call(account_id: "acc-2")).to eq(Result.failure("the match was not found"))
    end

    it "rejects an already-deleted match" do
      call(user_id: "bob")
      expect(call(user_id: "bob")).to eq(Result.failure("the match was not found"))
    end

    it "appends nothing when deleting an already-deleted match" do
      call(user_id: "bob")
      expect { call(user_id: "bob") }.not_to change { deletions.count }
    end

    # Defensive: a match whose league has no LeagueCreated (a corrupt history)
    # is caught by the league guard rather than crashing on the closed? check.
    it "rejects when the match's league was never created" do
      register(match_id: "orphan", league_id: "ghost", account_id: "acc-1", home: [ "bob" ], away: [ "carol" ])
      expect(call(match_id: "orphan", league_id: "ghost", user_id: "bob"))
        .to eq(Result.failure("the league was not found"))
    end
  end

  describe "league lifecycle", :event_store do
    it "rejects a delete in a closed league" do
      close_league
      expect(call).to eq(Result.failure("the league is closed"))
    end

    it "appends nothing when the league is closed" do
      close_league
      call
      expect(deletions).to be_empty
    end
  end

  describe "successful deletion", :event_store do
    it "returns success with the match id" do
      expect(call).to eq(Result.success("m-1"))
    end

    it "appends a MatchDeleted event with the match and the deleter" do
      call(user_id: "bob")
      expect(deletions.sole.data).to eq(
        match_id: "m-1", league_id: "league-1", account_id: "acc-1", deleted_by_user_id: "bob"
      )
    end
  end

  # One command deletes either kind of match: the decision model says which
  # match the id named, and that picks the event.
  describe "multiplayer matches", :event_store do
    it "rejects a deleter who did not play in the match" do
      register_multiplayer
      expect(call(match_id: "mp-1", user_id: "dave"))
        .to eq(Result.failure("only players in the match can delete it"))
    end

    it "appends a MultiplayerMatchDeleted event, not a head-to-head one" do
      register_multiplayer
      call(match_id: "mp-1", user_id: "carol")
      expect(multiplayer_deletions.sole.data).to eq(
        match_id: "mp-1", league_id: "league-1", account_id: "acc-1", deleted_by_user_id: "carol"
      )
      expect(deletions).to be_empty
    end

    it "returns success with the match id" do
      register_multiplayer
      expect(call(match_id: "mp-1", user_id: "alice")).to eq(Result.success("mp-1"))
    end

    it "makes the match disappear from details" do
      register_multiplayer
      call(match_id: "mp-1", user_id: "alice")
      expect(Matches::MultiplayerMatchDetails.find(match_id: "mp-1")).to be_nil
    end

    it "rejects an already-deleted match" do
      register_multiplayer
      call(match_id: "mp-1", user_id: "alice")
      expect(call(match_id: "mp-1", user_id: "alice")).to eq(Result.failure("the match was not found"))
    end

    it "rejects a match reached through a different league (tenancy)" do
      register_multiplayer
      expect(call(match_id: "mp-1", league_id: "league-2", user_id: "alice"))
        .to eq(Result.failure("the match was not found"))
    end

    it "rejects a delete in a closed league" do
      register_multiplayer
      close_league
      expect(call(match_id: "mp-1", user_id: "alice")).to eq(Result.failure("the league is closed"))
    end

    it "asks for a retry when the append condition fails" do
      register_multiplayer
      allow(EventStore).to receive(:append).and_raise(DcbEventStore::ConditionNotMet)
      expect(call(match_id: "mp-1", user_id: "alice"))
        .to eq(Result.failure("the league changed while you were working - please retry"))
    end
  end

  describe "concurrency conflict", :event_store do
    it "asks for a retry when the decision model's append condition fails" do
      allow(EventStore).to receive(:append).and_raise(DcbEventStore::ConditionNotMet)
      expect(call).to eq(Result.failure("the league changed while you were working - please retry"))
    end

    it "loses the race against a league close that lands after the decision was read" do
      stale_decision = Matches::MatchDecision.read(match_id: "m-1", league_id: "league-1", account_id: "acc-1")
      close_league
      allow(EventStore).to receive(:decide).and_return(stale_decision)
      expect(call).to eq(Result.failure("the league changed while you were working - please retry"))
      expect(deletions).to be_empty
    end
  end
end
