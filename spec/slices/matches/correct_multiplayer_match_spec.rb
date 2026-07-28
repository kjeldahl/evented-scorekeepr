require "rails_helper"

RSpec.describe Matches::CorrectMultiplayerMatch do
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

  def register_match(league_id: "league-1", account_id: "acc-1", player_ids:, player_scores:,
                     registered_by_user_id: "alice")
    match_id = SecureRandom.uuid
    EventStore.append([ DcbEventStore::Event.new(
      type: "MultiplayerMatchRegistered",
      data: { match_id:, league_id:, account_id:, player_ids:, player_scores:, registered_by_user_id: },
      tags: [ "match:#{match_id}", "league:#{league_id}", "account:#{account_id}",
              *player_ids.map { |id| "player:#{id}" } ]
    ) ])
    match_id
  end

  def close_league(league_id: "league-1", account_id: "acc-1")
    EventStore.append([ DcbEventStore::Event.new(
      type: "LeagueClosed",
      data: { league_id:, account_id: },
      tags: [ "league:#{league_id}", "account:#{account_id}" ]
    ) ])
  end

  def call(match_id:, player_scores:, league_id: "league-1", account_id: "acc-1", user_id: "alice")
    described_class.call(
      match_id:, league_id:, account_id:, user_id:, player_scores:
    )
  end

  def correction_events
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[MultiplayerMatchResultCorrected]) ])
    )
  end

  before do
    %w[alice bob carol dave].each { make_member(_1) }
    create_league
  end

  describe "input validation", :event_store do
    it "rejects a non-integer score" do
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      expect(call(match_id:, player_scores: { "alice" => "10.5", "bob" => "5" }))
        .to eq(Result.failure("scores must be integers"))
    end

    it "accepts negative scores" do
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      result = call(match_id:, player_scores: { "alice" => "-50", "bob" => "10" })
      expect(result).to be_success
    end
  end

  describe "decision invariants", :event_store do
    it "rejects a non-participant" do
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      expect(call(match_id:, player_scores: { "alice" => 12, "bob" => 6 }, user_id: "dave"))
        .to eq(Result.failure("only players in the match can correct it"))
    end

    it "rejects a closed league" do
      close_league
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      expect(call(match_id:, player_scores: { "alice" => 12, "bob" => 6 }))
        .to eq(Result.failure("the league is closed"))
    end

    it "rejects an unknown match" do
      expect(call(match_id: "missing", player_scores: { "alice" => 12, "bob" => 6 }))
        .to eq(Result.failure("the match was not found"))
    end

    # This command owns multiplayer matches; EditMatch owns head-to-head ones,
    # so a head-to-head id is not a match this command can find.
    it "rejects a head-to-head match id" do
      EventStore.append([ DcbEventStore::Event.new(
        type: "MatchRegistered",
        data: { match_id: "h2h-1", league_id: "league-1", account_id: "acc-1",
                home_player_ids: %w[alice], away_player_ids: %w[bob],
                home_score: 21, away_score: 8, registered_by_user_id: "alice" },
        tags: [ "match:h2h-1", "league:league-1", "account:acc-1", "player:alice", "player:bob" ]
      ) ])
      expect(call(match_id: "h2h-1", player_scores: { "alice" => 12, "bob" => 6 }))
        .to eq(Result.failure("the match was not found"))
      expect(correction_events).to be_empty
    end

    it "rejects a deleted match" do
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      EventStore.append([ DcbEventStore::Event.new(
        type: "MultiplayerMatchDeleted",
        data: { match_id:, league_id: "league-1", account_id: "acc-1", deleted_by_user_id: "alice" },
        tags: [ "match:#{match_id}", "league:league-1", "account:acc-1" ]
      ) ])
      expect(call(match_id:, player_scores: { "alice" => 12, "bob" => 6 }))
        .to eq(Result.failure("the match was not found"))
    end

    it "appends nothing on rejection" do
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      call(match_id:, player_scores: { "alice" => "10.5", "bob" => "5" })
      expect(correction_events).to be_empty
    end
  end

  describe "successful correction", :event_store do
    it "returns success with the match id" do
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      expect(call(match_id:, player_scores: { "alice" => 12, "bob" => 6 })).to eq(Result.success(match_id))
    end

    it "appends a MultiplayerMatchResultCorrected event with the whole scoreline" do
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      call(match_id:, player_scores: { "alice" => 12, "bob" => 6 }, user_id: "alice")
      event = correction_events.sole
      expect(event.type).to eq("MultiplayerMatchResultCorrected")
      expect(event.data).to eq(
        match_id:, league_id: "league-1", account_id: "acc-1",
        player_scores: { alice: 12, bob: 6 }, corrected_by_user_id: "alice"
      )
    end

    it "stores scores submitted as strings as integers" do
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      call(match_id:, player_scores: { "alice" => "12", "bob" => "6" }, user_id: "alice")
      expect(correction_events.sole.data[:player_scores]).to eq({ alice: 12, bob: 6 })
    end

    it "preserves the original player_ids (players are fixed)" do
      match_id = register_match(player_ids: %w[alice bob carol],
                                player_scores: { "alice" => 10, "bob" => 5, "carol" => 0 })
      call(match_id:, player_scores: { "alice" => 15, "bob" => 8, "carol" => 2 }, user_id: "alice")
      details = Matches::MultiplayerMatchDetails.find(match_id:)
      expect(details.player_ids).to eq(%w[alice bob carol])
      expect(details.player_scores).to eq({ alice: 15, bob: 8, carol: 2 })
    end
  end

  describe "concurrency conflict", :event_store do
    it "asks for a retry when the append condition fails" do
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      allow(EventStore).to receive(:append).and_raise(DcbEventStore::ConditionNotMet)
      expect(call(match_id:, player_scores: { "alice" => 12, "bob" => 6 }))
        .to eq(Result.failure("the league changed while you were working — please retry"))
    end

    it "loses the race against a league close that lands after the decision was read" do
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      stale_decision = Matches::MatchDecision.read(match_id:, league_id: "league-1", account_id: "acc-1")
      close_league
      allow(EventStore).to receive(:decide).and_return(stale_decision)
      expect(call(match_id:, player_scores: { "alice" => 12, "bob" => 6 }))
        .to eq(Result.failure("the league changed while you were working - please retry"))
      expect(correction_events).to be_empty
    end
  end
end
