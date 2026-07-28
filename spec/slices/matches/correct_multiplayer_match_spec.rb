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
    it "returns success" do
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      result = call(match_id:, player_scores: { "alice" => 12, "bob" => 6 })
      expect(result).to be_success
    end

    it "appends a MultiplayerMatchResultCorrected event" do
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      result = call(match_id:, player_scores: { "alice" => 12, "bob" => 6 }, user_id: "alice")
      expect(result).to be_success, "call failed: #{result.error}"
      event = correction_events.find { |e| e.data[:match_id] == match_id } or raise "no correction event found"
      expect(event.type).to eq("MultiplayerMatchResultCorrected")
      expect(event.data).to include(match_id:)
      expect(event.data[:player_scores]).to include({ alice: 12, bob: 6 })
      expect(event.data[:corrected_by_user_id]).to eq("alice")
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
  end
end
