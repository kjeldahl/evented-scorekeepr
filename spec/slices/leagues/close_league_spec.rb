require "rails_helper"

RSpec.describe Leagues::CloseLeague do
  def make_member(account_id: "acc-1", user_id: "owner-1")
    EventStore.append([ DcbEventStore::Event.new(
      type: "AccountCreated",
      data: { account_id:, name: "Office", owner_user_id: user_id },
      tags: [ "account:#{account_id}", "user:#{user_id}" ]
    ) ])
  end

  def create_league(league_id: "league-1", account_id: "acc-1")
    EventStore.append([ Leagues::Events.league_created(
      league_id:, account_id:, name: "Foosball Spring",
      game_type: "Foosball", starting_points: 1000, stake_percentage: 10
    ) ])
  end

  def call(league_id: "league-1", account_id: "acc-1", user_id: "owner-1")
    described_class.call(league_id:, account_id:, user_id:)
  end

  def closed_events
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[LeagueClosed]) ])
    )
  end

  describe "membership invariant", :event_store do
    before do
      make_member
      create_league
    end

    it "rejects a non-member" do
      expect(call(user_id: "stranger-1")).to eq(Result.failure("only members can close leagues"))
    end

    it "appends nothing for a non-member" do
      call(user_id: "stranger-1")
      expect(closed_events).to be_empty
    end
  end

  describe "league lookup", :event_store do
    before { make_member }

    it "rejects closing a league that does not exist" do
      expect(call).to eq(Result.failure("the league was not found"))
    end

    it "rejects closing a league through a different account (tenancy)" do
      make_member(account_id: "acc-2", user_id: "owner-1")
      create_league(account_id: "acc-2")
      expect(call(account_id: "acc-1")).to eq(Result.failure("the league was not found"))
    end

    it "appends nothing when the league was not found" do
      call
      expect(closed_events).to be_empty
    end
  end

  describe "closing once", :event_store do
    before do
      make_member
      create_league
    end

    it "returns success with the league id" do
      expect(call).to eq(Result.success("league-1"))
    end

    it "appends a LeagueClosed event tagged league and account" do
      call
      event = closed_events.sole
      expect(event.type).to eq("LeagueClosed")
      expect(event.data).to eq(league_id: "league-1", account_id: "acc-1")
      expect(event.tags).to contain_exactly("league:league-1", "account:acc-1")
    end

    it "rejects closing an already-closed league" do
      call
      expect(call).to eq(Result.failure("the league is closed"))
    end

    it "appends only one LeagueClosed event across repeated closes" do
      call
      call
      expect(closed_events.count).to eq(1)
    end
  end

  describe "concurrency conflict", :event_store do
    it "reports the league as closed when a concurrent close wins the race" do
      make_member
      create_league
      allow(EventStore).to receive(:append).and_raise(DcbEventStore::ConditionNotMet)
      expect(call).to eq(Result.failure("the league is closed"))
    end
  end
end
