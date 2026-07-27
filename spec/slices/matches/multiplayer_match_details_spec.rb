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
