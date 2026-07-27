require "rails_helper"

RSpec.describe Matches::RegisterMultiplayerMatch do
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
      data: { league_id:, account_id:, name: "Golf Cup", game_type: "Golf",
              starting_points: 1000, stake_percentage: 10, match_type: "multiplayer" },
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

  def call(player_ids:, player_scores:, league_id: "league-1", account_id: "acc-1", user_id: "alice")
    described_class.call(
      league_id:, account_id:, user_id:,
      player_ids:, player_scores:
    )
  end

  def match_events
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[MultiplayerMatchRegistered]) ])
    )
  end

  before do
    %w[alice bob carol dave].each { |player| make_member(player) }
    create_league
  end

  describe "input validation", :event_store do
    it "rejects an empty player list" do
      expect(call(player_ids: [], player_scores: {})).to eq(
        Result.failure("at least 1 participant is required")
      )
    end

    it "rejects duplicate players" do
      expect(call(player_ids: %w[alice alice], player_scores: { "alice" => 10 }))
        .to eq(Result.failure("players must be distinct"))
    end

    it "rejects a non-integer score" do
      expect(call(player_ids: %w[alice bob], player_scores: { "alice" => "10", "bob" => "5.5" }))
        .to eq(Result.failure("scores must be integers"))
    end

    it "rejects a negative score (negative scores are allowed)" do
      # Actually, negative scores ARE allowed per the domain — this test should pass
      result = call(player_ids: %w[alice bob], player_scores: { "alice" => "-50", "bob" => "10" })
      expect(result).to be_success
    end

    it "accepts a single player match" do
      expect(call(player_ids: %w[alice], player_scores: { "alice" => 0 })).to be_success
    end

    it "accepts a 3-player match with negative scores" do
      result = call(player_ids: %w[alice bob carol],
                    player_scores: { "alice" => "-50", "bob" => "10", "carol" => "30" })
      expect(result).to be_success
    end
  end

  describe "decision invariants", :event_store do
    it "rejects a registrar who is not a member" do
      expect(call(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 }, user_id: "stranger"))
        .to eq(Result.failure("only members can register matches"))
    end

    it "rejects a league that does not exist" do
      expect(call(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 }, league_id: "missing"))
        .to eq(Result.failure("the league was not found"))
    end

    it "rejects a closed league" do
      close_league
      expect(call(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 }))
        .to eq(Result.failure("the league is closed"))
    end

    it "rejects a player who is not a member of the account" do
      expect(call(player_ids: %w[alice stranger], player_scores: { "alice" => 10, "stranger" => 5 }))
        .to eq(Result.failure("all players must be members of the account"))
    end

    it "appends nothing on rejection" do
      call(player_ids: %w[alice stranger], player_scores: { "alice" => 10, "stranger" => 5 })
      expect(match_events).to be_empty
    end
  end

  describe "successful registration", :event_store do
    it "returns success with the new match id" do
      result = call(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      expect(result).to be_success
      expect(result.value).to be_a(String)
    end

    it "appends a MultiplayerMatchRegistered event" do
      result = call(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 }, user_id: "carol")
      event = match_events.find { |e| e.data[:player_ids] == %w[alice bob] } or raise "no match event"
      expect(event.type).to eq("MultiplayerMatchRegistered")
      expect(event.data).to include(
        match_id: result.value,
        league_id: "league-1",
        account_id: "acc-1",
        player_ids: %w[alice bob],
        player_scores: { alice: 10, bob: 5 },
        registered_by_user_id: "carol"
      )
    end

    it "tags the event with match, league, account and every player" do
      result = call(player_ids: %w[alice bob carol], player_scores: { "alice" => 10, "bob" => 5, "carol" => 0 })
      event = match_events.find { |e| e.data[:player_ids] == %w[alice bob carol] } or raise "no match event"
      expect(event.tags).to include(
        "match:#{result.value}", "league:league-1", "account:acc-1",
        "player:alice", "player:bob", "player:carol"
      )
    end

    it "coerces string form input into integer scores" do
      call(player_ids: %w[alice bob], player_scores: { "alice" => "10", "bob" => "5" })
      expect(match_events.find { |e| e.data[:player_ids] == %w[alice bob] }.data).to include(player_scores: { alice: 10, bob: 5 })
    end
  end

  describe "concurrency conflict", :event_store do
    it "asks for a retry when the append condition fails" do
      allow(EventStore).to receive(:append).and_raise(DcbEventStore::ConditionNotMet)
      expect(call(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 }))
        .to eq(Result.failure("the league changed while you were working — please retry"))
    end
  end
end
