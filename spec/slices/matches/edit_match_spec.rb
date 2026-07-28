require "rails_helper"

RSpec.describe Matches::EditMatch do
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

  def call(match_id: "m-1", league_id: "league-1", account_id: "acc-1", user_id: "bob",
           home_score: 21, away_score: 18)
    described_class.call(match_id:, league_id:, account_id:, user_id:, home_score:, away_score:)
  end

  def corrections
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[MatchResultCorrected]) ])
    )
  end

  before do
    create_league
    register
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

    it "rejects a non-numeric score" do
      expect(call(home_score: "abc")).to eq(Result.failure("scores must be non-negative integers"))
    end

    it "rejects a fractional score" do
      expect(call(home_score: "21.5")).to eq(Result.failure("scores must be non-negative integers"))
    end

    it "rejects a draw" do
      expect(call(home_score: 10, away_score: 10)).to eq(Result.failure("draws are not allowed"))
    end

    it "accepts a score padded with whitespace" do
      expect(call(home_score: " 21 ", away_score: 18)).to be_success
    end

    it "appends nothing when the score is invalid" do
      call(home_score: 10, away_score: 10)
      expect(corrections).to be_empty
    end
  end

  describe "authorisation", :event_store do
    it "rejects an editor who did not play in the match" do
      expect(call(user_id: "carol")).to eq(Result.failure("only players in the match can edit it"))
    end

    it "lets a losing player who did not register the match edit it" do
      expect(call(user_id: "bob")).to be_success
    end

    it "lets either winner of a 2v2 edit it" do
      register(match_id: "m-2", home: %w[alice carol], away: %w[bob dave], home_score: 10, away_score: 4)
      expect(call(match_id: "m-2", user_id: "dave", home_score: 21, away_score: 19)).to be_success
    end

    it "appends nothing when the editor did not play" do
      call(user_id: "carol")
      expect(corrections).to be_empty
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

    # This command owns head-to-head matches; CorrectMultiplayerMatch owns the
    # others, so a multiplayer id is not a match this command can find.
    it "rejects a multiplayer match id" do
      EventStore.append([ DcbEventStore::Event.new(
        type: "MultiplayerMatchRegistered",
        data: { match_id: "mp-1", league_id: "league-1", account_id: "acc-1",
                player_ids: %w[bob carol], player_scores: { "bob" => 9, "carol" => 4 },
                registered_by_user_id: "bob" },
        tags: [ "match:mp-1", "league:league-1", "account:acc-1", "player:bob", "player:carol" ]
      ) ])
      expect(call(match_id: "mp-1", user_id: "bob")).to eq(Result.failure("the match was not found"))
      expect(corrections).to be_empty
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
    it "rejects an edit in a closed league" do
      close_league
      expect(call).to eq(Result.failure("the league is closed"))
    end

    it "appends nothing when the league is closed" do
      close_league
      call
      expect(corrections).to be_empty
    end
  end

  describe "successful correction", :event_store do
    it "returns success with the match id" do
      expect(call).to eq(Result.success("m-1"))
    end

    it "appends a MatchResultCorrected event with the new score and the editor" do
      call(user_id: "bob", home_score: 21, away_score: 18)
      expect(corrections.sole.data).to eq(
        match_id: "m-1", league_id: "league-1", account_id: "acc-1",
        home_score: 21, away_score: 18, corrected_by_user_id: "bob"
      )
    end

    it "coerces string form input into integer scores" do
      call(home_score: "21", away_score: "18")
      expect(corrections.sole.data).to include(home_score: 21, away_score: 18)
    end

    it "can flip the winner by swapping the score" do
      expect(call(home_score: 8, away_score: 21)).to be_success
    end
  end

  describe "concurrency conflict", :event_store do
    it "asks for a retry when the decision model's append condition fails" do
      allow(EventStore).to receive(:append).and_raise(DcbEventStore::ConditionNotMet)
      expect(call).to eq(Result.failure("the league changed while you were working — please retry"))
    end

    it "loses the race against a league close that lands after the decision was read" do
      stale_decision = Matches::MatchDecision.read(match_id: "m-1", league_id: "league-1", account_id: "acc-1")
      close_league
      allow(EventStore).to receive(:decide).and_return(stale_decision)
      expect(call).to eq(Result.failure("the league changed while you were working — please retry"))
      expect(corrections).to be_empty
    end
  end
end
