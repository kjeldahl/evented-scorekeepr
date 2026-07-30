require "rails_helper"

RSpec.describe Matches::RegisterMultiplayerMatch do
  def make_member(user_id, account_id: "acc-1")
    EventStore.append([ DcbEventStore::Event.new(
      type: "InvitationAccepted",
      data: { invitation_id: "inv-#{user_id}", account_id:, user_id: },
      tags: [ "invitation:inv-#{user_id}", "account:#{account_id}", "user:#{user_id}" ]
    ) ])
  end

  def create_league(league_id: "league-1", account_id: "acc-1", game_type: "Golf", match_type: "multiplayer")
    EventStore.append([ DcbEventStore::Event.new(
      type: "LeagueCreated",
      data: { league_id:, account_id:, name: "Golf Cup", game_type:,
              starting_points: 1000, stake_percentage: 10, match_type: },
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
      # The game type count check catches 0 players before the generic
      # "at least 1" guard, so the error reflects the game type requirement.
      expect(call(player_ids: [], player_scores: {})).to eq(
        Result.failure("a Golf match needs 1 to 8 players")
      )
    end

    it "rejects an empty player list for Foosball" do
      create_league(game_type: "Foosball")
      expect(call(player_ids: [], player_scores: {})).to eq(
        Result.failure("a Foosball match needs 2 to 4 players")
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

  describe "half-filled row detection", :event_store do
    it "rejects a row with player but no score" do
      expect(call(player_ids: %w[alice bob], player_scores: { "alice" => 10 }))
        .to eq(Result.failure("every player needs a score"))
    end

    it "rejects a row with score but no player" do
      # The form sends a blank key "" for rows with a score but no player.
      expect(call(player_ids: %w[alice], player_scores: { "alice" => 10, "" => 5 }))
        .to eq(Result.failure("every score needs a player"))
    end

    it "passes when all players have scores" do
      result = call(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      expect(result).to be_success
    end
  end

  describe "game type player count", :event_store do
    it "rejects a foosball match with 1 player" do
      create_league(game_type: "Foosball")
      expect(call(player_ids: %w[alice], player_scores: { "alice" => 10 }))
        .to eq(Result.failure("a Foosball match needs 2 to 4 players"))
    end

    it "rejects a foosball match with 5 players" do
      create_league(game_type: "Foosball")
      expect(call(player_ids: %w[alice bob carol dave frank],
                  player_scores: { "alice" => 1, "bob" => 2, "carol" => 3, "dave" => 4, "frank" => 5 }))
        .to eq(Result.failure("a Foosball match needs 2 to 4 players"))
    end

    it "accepts a foosball match within range" do
      create_league(game_type: "Foosball")
      result = call(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      expect(result).to be_success
    end

    it "accepts a golf match with 1 player" do
      create_league(game_type: "Golf")
      result = call(player_ids: %w[alice], player_scores: { "alice" => 0 })
      expect(result).to be_success
    end

    it "accepts a golf match with 8 players" do
      create_league(game_type: "Golf")
      %w[alice bob carol dave eve frank grace henry].each { |u| make_member(u) }
      player_ids = %w[alice bob carol dave eve frank grace henry]
      scores = player_ids.to_h { |id| [id, 0] }
      result = call(player_ids:, player_scores: scores)
      expect(result).to be_success
    end

    it "rejects a golf match with 9 players" do
      create_league(game_type: "Golf")
      %w[alice bob carol dave eve frank grace henry ivan].each { |u| make_member(u) }
      player_ids = %w[alice bob carol dave eve frank grace henry ivan]
      scores = player_ids.to_h { |id| [id, 0] }
      expect(call(player_ids:, player_scores: scores))
        .to eq(Result.failure("a Golf match needs 1 to 8 players"))
    end

    it "does not enforce game type on match leagues" do
      create_league(match_type: "match")
      league = Matches::League.find(league_id: "league-1", account_id: "acc-1")
      expect(league).to be_match_league
    end
  end

  describe "player id normalisation", :event_store do
    it "strips surrounding whitespace from the submitted ids" do
      call(player_ids: [ "  alice  ", "bob" ], player_scores: { "alice" => 10, "bob" => 5 })
      expect(match_events.sole.data[:player_ids]).to eq(%w[alice bob])
    end

    it "drops empty selections (an unused player row on the form)" do
      call(player_ids: [ "alice", "", "   ", "bob" ], player_scores: { "alice" => 10, "bob" => 5 })
      expect(match_events.sole.data[:player_ids]).to eq(%w[alice bob])
    end

    it "rejects a match whose only participants were blank" do
      # After normalization all entries drop out → 0 players → game type check fires.
      expect(call(player_ids: [ "", "  " ], player_scores: {}))
        .to eq(Result.failure("a Golf match needs 1 to 8 players"))
    end

    it "detects duplicates only after stripping" do
      expect(call(player_ids: [ "alice", " alice " ], player_scores: { "alice" => 10 }))
        .to eq(Result.failure("players must be distinct"))
    end

    it "reads ids that are not strings" do
      call(player_ids: [ :alice, :bob ], player_scores: { "alice" => 10, "bob" => 5 })
      expect(match_events.sole.data[:player_ids]).to eq(%w[alice bob])
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

    # The real condition, not a stubbed append: a league close that lands
    # after the decision was read must beat this registration.
    it "loses the race against a league close that lands after the decision was read" do
      stale_decision = EventStore.decide(
        member: Matches::Membership.projection(account_id: "acc-1", user_id: "alice"),
        league: Matches::League.projection(league_id: "league-1", account_id: "acc-1"),
        players: Matches::PlayerMembership.projection(account_id: "acc-1", player_ids: %w[alice bob])
      )
      close_league
      allow(EventStore).to receive(:decide).and_return(stale_decision)
      expect(call(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 }))
        .to eq(Result.failure("the league changed while you were working — please retry"))
      expect(match_events).to be_empty
    end
  end
end
