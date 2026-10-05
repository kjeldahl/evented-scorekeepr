require "rails_helper"

RSpec.describe Matches::Events do
  describe ".match_registered" do
    def build(home_player_ids: [ "alice-1" ], away_player_ids: [ "bob-1" ], home_score: 21, away_score: 8)
      described_class.match_registered(
        match_id: "match-1", league_id: "league-1", account_id: "acc-1",
        home_player_ids:, away_player_ids:, home_score:, away_score:,
        registered_by_user_id: "alice-1"
      )
    end

    it "has the MatchRegistered type" do
      expect(build.type).to eq("MatchRegistered")
    end

    it "carries the sides, the score and the registrar as data" do
      expect(build.data).to eq(
        match_id: "match-1", league_id: "league-1", account_id: "acc-1",
        home_player_ids: [ "alice-1" ], away_player_ids: [ "bob-1" ],
        home_score: 21, away_score: 8, registered_by_user_id: "alice-1"
      )
    end

    it "tags a 1v1 match with match, league, account and both players" do
      expect(build.tags).to contain_exactly(
        "match:match-1", "league:league-1", "account:acc-1", "player:alice-1", "player:bob-1"
      )
    end

    it "tags a 2v2 match with every one of the four players" do
      event = build(home_player_ids: %w[alice-1 carol-1], away_player_ids: %w[bob-1 dave-1])
      expect(event.tags).to contain_exactly(
        "match:match-1", "league:league-1", "account:acc-1",
        "player:alice-1", "player:carol-1", "player:bob-1", "player:dave-1"
      )
    end
  end

  describe ".match_result_corrected" do
    def build(home_score: 21, away_score: 18)
      described_class.match_result_corrected(
        match_id: "match-1", league_id: "league-1", account_id: "acc-1",
        home_score:, away_score:, corrected_by_user_id: "bob-1"
      )
    end

    it "has the MatchResultCorrected type" do
      expect(build.type).to eq("MatchResultCorrected")
    end

    it "carries the match, league, account, the new score and the editor as data" do
      expect(build.data).to eq(
        match_id: "match-1", league_id: "league-1", account_id: "acc-1",
        home_score: 21, away_score: 18, corrected_by_user_id: "bob-1"
      )
    end

    it "tags only the match, league and account - the sides are unchanged" do
      expect(build.tags).to contain_exactly("match:match-1", "league:league-1", "account:acc-1")
    end
  end

  describe ".match_deleted" do
    def build
      described_class.match_deleted(
        match_id: "match-1", league_id: "league-1", account_id: "acc-1", deleted_by_user_id: "bob-1"
      )
    end

    it "has the MatchDeleted type" do
      expect(build.type).to eq("MatchDeleted")
    end

    it "carries the match, league, account and the deleter as data" do
      expect(build.data).to eq(
        match_id: "match-1", league_id: "league-1", account_id: "acc-1", deleted_by_user_id: "bob-1"
      )
    end

    it "tags only the match, league and account - the sides are gone" do
      expect(build.tags).to contain_exactly("match:match-1", "league:league-1", "account:acc-1")
    end
  end

  describe ".multiplayer_match_registered" do
    def build(player_ids: %w[alice-1 bob-1 carol-1])
      described_class.multiplayer_match_registered(
        match_id: "match-1", league_id: "league-1", account_id: "acc-1", player_ids:,
        player_scores: { "alice-1": 10, "bob-1": -3, "carol-1": 0 }, registered_by_user_id: "alice-1"
      )
    end

    it "has the MultiplayerMatchRegistered type" do
      expect(build.type).to eq("MultiplayerMatchRegistered")
    end

    it "carries the players, their scores and the registrar as data" do
      expect(build.data).to eq(
        match_id: "match-1", league_id: "league-1", account_id: "acc-1",
        player_ids: %w[alice-1 bob-1 carol-1],
        player_scores: { "alice-1": 10, "bob-1": -3, "carol-1": 0 }, registered_by_user_id: "alice-1"
      )
    end

    it "tags the match with match, league, account and every player" do
      expect(build.tags).to eq(
        [ "match:match-1", "league:league-1", "account:acc-1", "player:alice-1", "player:bob-1", "player:carol-1" ]
      )
    end

    it "tags a single-player match with that one player" do
      expect(build(player_ids: %w[alice-1]).tags).to eq(
        [ "match:match-1", "league:league-1", "account:acc-1", "player:alice-1" ]
      )
    end
  end

  describe ".multiplayer_match_result_corrected" do
    def build
      described_class.multiplayer_match_result_corrected(
        match_id: "match-1", league_id: "league-1", account_id: "acc-1",
        player_scores: { "alice-1": 7, "bob-1": 9 }, corrected_by_user_id: "bob-1"
      )
    end

    it "has the MultiplayerMatchResultCorrected type" do
      expect(build.type).to eq("MultiplayerMatchResultCorrected")
    end

    it "carries the match, league, account, the new scores and the editor as data" do
      expect(build.data).to eq(
        match_id: "match-1", league_id: "league-1", account_id: "acc-1",
        player_scores: { "alice-1": 7, "bob-1": 9 }, corrected_by_user_id: "bob-1"
      )
    end

    it "tags only the match, league and account - the players are unchanged" do
      expect(build.tags).to eq([ "match:match-1", "league:league-1", "account:acc-1" ])
    end
  end

  describe ".multiplayer_match_deleted" do
    def build
      described_class.multiplayer_match_deleted(
        match_id: "match-1", league_id: "league-1", account_id: "acc-1", deleted_by_user_id: "bob-1"
      )
    end

    it "has the MultiplayerMatchDeleted type" do
      expect(build.type).to eq("MultiplayerMatchDeleted")
    end

    it "carries the match, league, account and the deleter as data" do
      expect(build.data).to eq(
        match_id: "match-1", league_id: "league-1", account_id: "acc-1", deleted_by_user_id: "bob-1"
      )
    end

    it "tags only the match, league and account - the players are gone" do
      expect(build.tags).to eq([ "match:match-1", "league:league-1", "account:acc-1" ])
    end
  end
end
