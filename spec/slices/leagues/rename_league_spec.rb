require "rails_helper"

RSpec.describe Leagues::RenameLeague do
  def create_account
    # The leagues slice folds the accounts slice's membership events; the
    # spec builds them raw per the docs/DOMAIN.md contract.
    EventStore.append([ DcbEventStore::Event.new(
      type: "AccountCreated",
      data: { account_id: "acc-1", name: "Office", owner_user_id: "user-1" },
      tags: [ "account:acc-1", "user:user-1" ]
    ) ])
    "acc-1"
  end

  def create_league(account_id)
    Leagues::CreateLeague.call(
      account_id:, user_id: "user-1", name: "Foosball Spring", game_type: "Foosball"
    ).value
  end

  def call(league_id:, account_id: "acc-1", user_id: "user-1", name: "Foosball Summer")
    described_class.call(league_id:, account_id:, user_id:, name:)
  end

  def renamed_events
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[LeagueRenamed]) ])
    )
  end

  describe "input validation", :event_store do
    it "rejects a blank name without reading or writing" do
      expect(call(league_id: "league-1", name: "  ")).to eq(Result.failure("name is required"))
      expect(renamed_events).to be_empty
    end

    it "rejects a missing name instead of raising" do
      expect(call(league_id: "league-1", name: nil)).to eq(Result.failure("name is required"))
    end
  end

  describe "membership invariant", :event_store do
    it "rejects a non-member" do
      league_id = create_league(create_account)
      result = call(league_id:, user_id: "stranger")
      expect(result).to eq(Result.failure("only members can rename leagues"))
      expect(renamed_events).to be_empty
    end
  end

  describe "league lifecycle", :event_store do
    it "rejects renaming an unknown league" do
      create_account
      expect(call(league_id: "missing")).to eq(Result.failure("the league was not found"))
    end

    it "rejects renaming a closed league" do
      league_id = create_league(create_account)
      Leagues::CloseLeague.call(league_id:, account_id: "acc-1", user_id: "user-1")
      expect(call(league_id:)).to eq(Result.failure("the league is closed"))
      expect(renamed_events).to be_empty
    end

    it "loses the race against a close that lands after the decision was read" do
      league_id = create_league(create_account)
      stale_decision = EventStore.decide(
        league: Leagues::LeagueState.projection(league_id:, account_id: "acc-1"),
        member: Leagues::Membership.projection(account_id: "acc-1", user_id: "user-1")
      )
      Leagues::CloseLeague.call(league_id:, account_id: "acc-1", user_id: "user-1")
      allow(EventStore).to receive(:decide).and_return(stale_decision)
      expect(call(league_id:)).to eq(Result.failure("the league is closed"))
      expect(renamed_events).to be_empty
    end
  end

  describe "successful rename", :event_store do
    it "returns success with the league id" do
      league_id = create_league(create_account)
      expect(call(league_id:)).to eq(Result.success(league_id))
    end

    it "appends a LeagueRenamed event tagged with league and account" do
      league_id = create_league(create_account)
      call(league_id:, name: "Foosball Summer")
      event = renamed_events.sole
      expect(event.data).to eq(league_id:, account_id: "acc-1", name: "Foosball Summer")
      expect(event.tags).to contain_exactly("league:#{league_id}", "account:acc-1")
    end

    it "strips surrounding whitespace from the name" do
      league_id = create_league(create_account)
      call(league_id:, name: "  Foosball Summer  ")
      expect(renamed_events.sole.data[:name]).to eq("Foosball Summer")
    end

    it "changes the league's name in the summary read model" do
      league_id = create_league(create_account)
      call(league_id:, name: "Foosball Summer")
      expect(Leagues::League.find(league_id).name).to eq("Foosball Summer")
    end

    it "keeps the league open and renameable again (latest name wins)" do
      league_id = create_league(create_account)
      call(league_id:, name: "Foosball Summer")
      call(league_id:, name: "Foosball Autumn")
      league = Leagues::League.find(league_id)
      expect(league.name).to eq("Foosball Autumn")
      expect(league).to be_open
    end
  end
end
