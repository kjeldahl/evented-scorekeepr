require "rails_helper"

RSpec.describe Matches::DeleteMultiplayerMatch do
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

  def call(match_id:, league_id: "league-1", account_id: "acc-1", user_id: "alice")
    described_class.call(match_id:, league_id:, account_id:, user_id:)
  end

  def deletion_events
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[MultiplayerMatchDeleted]) ])
    )
  end

  before do
    %w[alice bob carol dave].each { make_member(_1) }
    create_league
  end

  describe "decision invariants", :event_store do
    it "rejects a non-participant" do
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      expect(call(match_id:, user_id: "dave"))
        .to eq(Result.failure("only players in the match can delete it"))
    end

    it "rejects a closed league" do
      close_league
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      expect(call(match_id:)).to eq(Result.failure("the league is closed"))
    end

    it "rejects an unknown match" do
      expect(call(match_id: "missing"))
        .to eq(Result.failure("the match was not found"))
    end

    it "rejects a deleted match (already deleted)" do
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      call(match_id:) # first delete succeeds
      expect(call(match_id:)).to eq(Result.failure("the match was not found"))
    end

    it "appends nothing on rejection" do
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      call(match_id:, user_id: "dave")
      expect(deletion_events).to be_empty
    end
  end

  describe "successful deletion", :event_store do
    it "returns success" do
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      result = call(match_id:)
      expect(result).to be_success
    end

    it "appends a MultiplayerMatchDeleted event" do
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      call(match_id:, user_id: "alice")
      event = deletion_events.find { |e| e.data[:match_id] == match_id } or raise "no deletion event found"
      expect(event.type).to eq("MultiplayerMatchDeleted")
      expect(event.data).to include(
        match_id:, league_id: "league-1", account_id: "acc-1",
        deleted_by_user_id: "alice"
      )
    end

    it "makes the match disappear from details" do
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      call(match_id:)
      expect(Matches::MultiplayerMatchDetails.find(match_id:)).to be_nil
    end
  end

  describe "concurrency conflict", :event_store do
    it "asks for a retry when the append condition fails" do
      match_id = register_match(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      allow(EventStore).to receive(:append).and_raise(DcbEventStore::ConditionNotMet)
      expect(call(match_id:))
        .to eq(Result.failure("the league changed while you were working — please retry"))
    end
  end
end
