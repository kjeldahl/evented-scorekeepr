require "rails_helper"

RSpec.describe Matches::MultiplayerMatchDetails do
  def event(match_id, data)
    DcbEventStore::Event.new(
      type: "MultiplayerMatchRegistered",
      data: { match_id:, league_id: "league-1", account_id: "acc-1", **data },
      tags: [ "match:#{match_id}", "league:league-1", "account:acc-1" ]
    )
  end

  def correction_event(match_id, data)
    DcbEventStore::Event.new(
      type: "MultiplayerMatchResultCorrected",
      data: { match_id:, league_id: "league-1", account_id: "acc-1", **data },
      tags: [ "match:#{match_id}", "league:league-1", "account:acc-1" ]
    )
  end

  def delete_event(match_id)
    DcbEventStore::Event.new(
      type: "MultiplayerMatchDeleted",
      data: { match_id:, league_id: "league-1", account_id: "acc-1", deleted_by_user_id: "alice" },
      tags: [ "match:#{match_id}", "league:league-1", "account:acc-1" ]
    )
  end

  before { EventStore.reset! }

  describe ".projection (pure fold)" do
    subject(:projection) { described_class.projection(match_id: "m-1") }

    def registered(player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 })
      event("m-1", player_ids:, player_scores:)
    end

    it "is nil for a match that was never registered" do
      expect(projection.fold([])).to be_nil
    end

    it "ignores a correction that arrives before any registration" do
      expect(projection.fold([ correction_event("m-1", player_scores: { "alice" => 1 }) ])).to be_nil
    end

    it "stays nil when a delete arrives before any registration" do
      expect(projection.fold([ delete_event("m-1") ])).to be_nil
    end

    it "folds MultiplayerMatchRegistered into the players, league, account and scores" do
      expect(projection.fold([ registered ])).to eq(Matches::MultiplayerMatchDetails::Details.new(
        match_id: "m-1", league_id: "league-1", account_id: "acc-1",
        player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 }, deleted: false
      ))
    end

    it "applies a later correction to the scores, leaving the players fixed" do
      details = projection.fold([ registered, correction_event("m-1", player_scores: { "alice" => 3, "bob" => 9 }) ])
      expect(details.player_scores).to eq({ "alice" => 3, "bob" => 9 })
      expect(details.player_ids).to eq(%w[alice bob])
    end

    it "marks the match deleted once MultiplayerMatchDeleted lands" do
      expect(projection.fold([ registered, delete_event("m-1") ])).to be_deleted
    end

    it "queries the match's own events by the match tag" do
      item = projection.query.items.sole
      expect(item.event_types)
        .to eq(%w[MultiplayerMatchRegistered MultiplayerMatchResultCorrected MultiplayerMatchDeleted])
      expect(item.tags).to eq([ "match:m-1" ])
    end
  end

  # The protocol MatchDetails::Details answers too, so commands acting on
  # "whichever match this id names" never ask which class they hold.
  describe "Details" do
    it "lists its players" do
      details = described_class.projection(match_id: "m-1")
                               .fold([ event("m-1", player_ids: %w[alice bob carol], player_scores: {}) ])
      expect(details.players).to eq(%w[alice bob carol])
    end

    it "is the multiplayer kind" do
      details = described_class.projection(match_id: "m-1")
                               .fold([ event("m-1", player_ids: %w[alice bob], player_scores: {}) ])
      expect(details.multiplayer?).to be(true)
    end
  end

  describe "find" do
    it "returns nil for an unknown match" do
      expect(described_class.find(match_id: "missing")).to be_nil
    end

    it "returns details for a registered match" do
      match_id = "m-1"
      EventStore.append(event(match_id, player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 }))
      details = described_class.find(match_id:)

      expect(details.match_id).to eq(match_id)
      expect(details.league_id).to eq("league-1")
      expect(details.account_id).to eq("acc-1")
      expect(details.player_ids).to eq(%w[alice bob])
      expect(details.player_scores).to eq({ alice: 10, bob: 5 })
      expect(details.deleted?).to be(false)
    end

    it "updates scores on correction" do
      match_id = "m-1"
      EventStore.append(event(match_id, player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 }))
      EventStore.append(correction_event(match_id, player_scores: { "alice" => 15, "bob" => 8 }))
      details = described_class.find(match_id:)

      expect(details.player_scores).to eq({ alice: 15, bob: 8 })
    end

    it "returns nil when the match is deleted" do
      match_id = "m-1"
      EventStore.append(event(match_id, player_ids: %w[alice bob], player_scores: { "alice" => 10, "bob" => 5 }))
      EventStore.append(delete_event(match_id))
      expect(described_class.find(match_id:)).to be_nil
    end
  end
end
