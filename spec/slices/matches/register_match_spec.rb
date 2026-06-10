require "rails_helper"

RSpec.describe Matches::RegisterMatch do
  # Membership and league lifecycle are folded from other slices' events
  # (the cross-slice contract), so the spec appends raw AccountCreated /
  # InvitationAccepted / LeagueCreated / LeagueClosed events as givens.
  def make_member(user_id, account_id: "acc-1")
    EventStore.append([ DcbEventStore::Event.new(
      type: "InvitationAccepted",
      data: { invitation_id: "inv-#{user_id}", account_id:, user_id: },
      tags: [ "invitation:inv-#{user_id}", "account:#{account_id}", "user:#{user_id}" ]
    ) ])
  end

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
      type: "LeagueClosed",
      data: { league_id:, account_id: },
      tags: [ "league:#{league_id}", "account:#{account_id}" ]
    ) ])
  end

  def call(home: [ "alice" ], away: [ "bob" ], home_score: 21, away_score: 8,
           league_id: "league-1", account_id: "acc-1", user_id: "alice")
    described_class.call(
      league_id:, account_id:, user_id:,
      home_player_ids: home, away_player_ids: away, home_score:, away_score:
    )
  end

  def match_events
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[MatchRegistered]) ])
    )
  end

  before do
    %w[alice bob carol dave].each { |player| make_member(player) }
    create_league
  end

  describe "side validation", :event_store do
    it "rejects an empty home side" do
      expect(call(home: [])).to eq(Result.failure("each side must have 1 or 2 players"))
    end

    it "rejects an away side of three players" do
      expect(call(away: %w[bob carol dave])).to eq(Result.failure("each side must have 1 or 2 players"))
    end

    it "treats blank and nil entries (empty form selects) as absent players" do
      expect(call(home: [ "alice", "" ], away: [ "bob", nil ])).to be_success
    end

    it "rejects a player on both sides of a 2v2 match" do
      expect(call(home: %w[alice bob], away: %w[bob carol])).to eq(
        Result.failure("a player cannot be on both sides")
      )
    end

    it "rejects a player playing against themselves" do
      expect(call(home: [ "alice" ], away: [ "alice" ])).to eq(
        Result.failure("a player cannot be on both sides")
      )
    end

    it "rejects a player appearing twice on the same side" do
      expect(call(home: %w[alice alice], away: [ "bob" ])).to eq(
        Result.failure("a player cannot be on both sides")
      )
    end
  end

  describe "score validation", :event_store do
    it "rejects a negative home score" do
      expect(call(home_score: -1)).to eq(Result.failure("scores must be non-negative integers"))
    end

    it "rejects a negative away score given as a string" do
      expect(call(away_score: "-3")).to eq(Result.failure("scores must be non-negative integers"))
    end

    it "rejects a blank score" do
      expect(call(home_score: "")).to eq(Result.failure("scores must be non-negative integers"))
    end

    it "rejects a nil score" do
      expect(call(away_score: nil)).to eq(Result.failure("scores must be non-negative integers"))
    end

    it "rejects a non-numeric score" do
      expect(call(home_score: "abc")).to eq(Result.failure("scores must be non-negative integers"))
    end

    it "rejects a fractional score" do
      expect(call(home_score: "1.5")).to eq(Result.failure("scores must be non-negative integers"))
    end

    it "rejects a draw" do
      expect(call(home_score: 10, away_score: 10)).to eq(Result.failure("draws are not allowed"))
    end

    it "rejects a 0-0 draw" do
      expect(call(home_score: 0, away_score: 0)).to eq(Result.failure("draws are not allowed"))
    end

    it "accepts a 0 score on the losing side" do
      expect(call(home_score: 21, away_score: 0)).to be_success
    end
  end

  describe "decision invariants", :event_store do
    it "rejects a registrar who is not a member" do
      expect(call(user_id: "stranger")).to eq(Result.failure("only members can register matches"))
    end

    it "rejects a league that does not exist" do
      expect(call(league_id: "missing")).to eq(Result.failure("the league was not found"))
    end

    it "rejects a league reached through a different account (tenancy)" do
      make_member("alice", account_id: "acc-2")
      expect(call(league_id: "league-1", account_id: "acc-2")).to eq(
        Result.failure("the league was not found")
      )
    end

    it "rejects a closed league" do
      close_league
      expect(call).to eq(Result.failure("the league is closed"))
    end

    it "rejects a home player who is not a member of the account" do
      expect(call(home: [ "eve" ], user_id: "bob", away: [ "bob" ])).to eq(
        Result.failure("all players must be members of the account")
      )
    end

    it "rejects an away player who is not a member of the account" do
      expect(call(away: %w[bob eve], home: %w[alice carol])).to eq(
        Result.failure("all players must be members of the account")
      )
    end

    it "appends nothing on rejection" do
      call(user_id: "stranger")
      call(league_id: "missing")
      call(home_score: 10, away_score: 10)
      expect(match_events).to be_empty
    end
  end

  describe "successful registration", :event_store do
    it "returns success with the new match id" do
      result = call
      expect(result).to be_success
      expect(result.value).to be_a(String)
    end

    it "generates a distinct match id per registration" do
      expect(call.value).not_to eq(call.value)
    end

    it "appends a MatchRegistered event with sides, score and registrar" do
      result = call(home: [ "alice" ], away: [ "bob" ], home_score: 21, away_score: 8, user_id: "carol")
      event = match_events.sole
      expect(event.type).to eq("MatchRegistered")
      expect(event.data).to eq(
        match_id: result.value, league_id: "league-1", account_id: "acc-1",
        home_player_ids: [ "alice" ], away_player_ids: [ "bob" ],
        home_score: 21, away_score: 8, registered_by_user_id: "carol"
      )
    end

    it "tags the event with match, league, account and every player of a 2v2" do
      result = call(home: %w[alice carol], away: %w[bob dave])
      expect(match_events.sole.tags).to contain_exactly(
        "match:#{result.value}", "league:league-1", "account:acc-1",
        "player:alice", "player:carol", "player:bob", "player:dave"
      )
    end

    it "coerces string form input into integer scores" do
      call(home_score: "21", away_score: "8")
      expect(match_events.sole.data).to include(home_score: 21, away_score: 8)
    end

    it "registers an away win (the score decides the winner, not the side)" do
      expect(call(home_score: 8, away_score: 21)).to be_success
    end
  end

  describe "concurrency conflict", :event_store do
    it "asks for a retry when the decision model's append condition fails" do
      allow(EventStore).to receive(:append).and_raise(DcbEventStore::ConditionNotMet)
      expect(call).to eq(
        Result.failure("the league changed while you were working — please retry")
      )
    end
  end
end
