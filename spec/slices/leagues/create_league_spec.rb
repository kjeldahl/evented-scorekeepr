require "rails_helper"

RSpec.describe Leagues::CreateLeague do
  # Membership is folded from the accounts slice's events (the cross-slice
  # contract), so the spec appends a raw AccountCreated to make owner-1 a
  # member of acc-1.
  def make_member(account_id: "acc-1", user_id: "owner-1")
    EventStore.append([ DcbEventStore::Event.new(
      type: "AccountCreated",
      data: { account_id:, name: "Office", owner_user_id: user_id },
      tags: [ "account:#{account_id}", "user:#{user_id}" ]
    ) ])
  end

  def call(name: "Foosball Spring", game_type: "Foosball", account_id: "acc-1", user_id: "owner-1", **settings)
    described_class.call(account_id:, user_id:, name:, game_type:, **settings)
  end

  def league_events
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[LeagueCreated]) ])
    )
  end

  describe "name validation", :event_store do
    it "rejects a blank name" do
      expect(call(name: "  ")).to eq(Result.failure("name is required"))
    end

    it "rejects a nil name" do
      expect(call(name: nil)).to eq(Result.failure("name is required"))
    end
  end

  describe "starting points validation", :event_store do
    it "rejects zero starting points" do
      expect(call(starting_points: 0)).to eq(Result.failure("starting points must be positive"))
    end

    it "rejects negative starting points" do
      expect(call(starting_points: -100)).to eq(Result.failure("starting points must be positive"))
    end

    it "rejects non-integer starting points" do
      expect(call(starting_points: "12.5")).to eq(Result.failure("starting points must be positive"))
    end

    it "rejects fractional starting points even as a number" do
      expect(call(starting_points: 12.5)).to eq(Result.failure("starting points must be positive"))
    end

    it "accepts starting points of 1 (the lower bound)" do
      make_member
      expect(call(starting_points: 1)).to be_success
    end
  end

  describe "stake validation", :event_store do
    it "rejects a stake of 0" do
      expect(call(stake_percentage: 0)).to eq(Result.failure("stake must be between 1 and 99"))
    end

    it "rejects a stake of 100" do
      expect(call(stake_percentage: 100)).to eq(Result.failure("stake must be between 1 and 99"))
    end

    it "rejects a non-integer stake" do
      expect(call(stake_percentage: "ten")).to eq(Result.failure("stake must be between 1 and 99"))
    end

    it "accepts a stake of 1 (the lower bound)" do
      make_member
      expect(call(stake_percentage: 1)).to be_success
    end

    it "accepts a stake of 99 (the upper bound)" do
      make_member
      expect(call(stake_percentage: 99)).to be_success
    end
  end

  describe "failed creation", :event_store do
    it "appends nothing when validation fails" do
      make_member
      call(name: "")
      expect(league_events).to be_empty
    end

    it "rejects a non-member" do
      make_member
      result = call(user_id: "stranger-1")
      expect(result).to eq(Result.failure("only members can create leagues"))
    end

    it "appends nothing for a non-member" do
      make_member
      call(user_id: "stranger-1")
      expect(league_events).to be_empty
    end

    it "rejects a member of a different account" do
      make_member(account_id: "acc-2")
      expect(call(account_id: "acc-1")).to eq(Result.failure("only members can create leagues"))
    end
  end

  describe "defaults", :event_store do
    before { make_member }

    it "defaults starting points to 1000 and stake to 10% when not given" do
      call
      expect(league_events.sole.data).to include(starting_points: 1000, stake_percentage: 10)
    end

    it "treats nil settings as the defaults" do
      call(starting_points: nil, stake_percentage: nil)
      expect(league_events.sole.data).to include(starting_points: 1000, stake_percentage: 10)
    end

    it "treats blank settings (cleared form fields) as the defaults" do
      call(starting_points: " ", stake_percentage: "")
      expect(league_events.sole.data).to include(starting_points: 1000, stake_percentage: 10)
    end
  end

  describe "successful creation", :event_store do
    before { make_member }

    it "returns success with the new league id" do
      result = call
      expect(result).to be_success
      expect(result.value).to be_a(String)
    end

    it "appends a LeagueCreated event with the settings, tagged league and account" do
      result = call(name: " Foosball Spring ", game_type: " Foosball ",
                    starting_points: 1500, stake_percentage: 20)
      event = league_events.sole
      expect(event.type).to eq("LeagueCreated")
      expect(event.data).to eq(
        league_id: result.value, account_id: "acc-1", name: "Foosball Spring",
        game_type: "Foosball", starting_points: 1500, stake_percentage: 20,
        match_type: "match"
      )
      expect(event.tags).to contain_exactly("league:#{result.value}", "account:acc-1")
    end

    it "coerces string form input into integers" do
      call(starting_points: "1500", stake_percentage: "20")
      expect(league_events.sole.data).to include(starting_points: 1500, stake_percentage: 20)
    end

    it "generates a distinct league id per creation" do
      expect(call.value).not_to eq(call.value)
    end

    it "stores a missing game type as blank rather than failing" do
      call(game_type: nil)
      expect(league_events.sole.data[:game_type]).to eq("")
    end

    it "appends with the decision model's append condition (concurrency guard)" do
      condition = nil
      allow(EventStore).to receive(:append) { |_event, append_condition| condition = append_condition }
      call
      expect(condition).to be_a(DcbEventStore::AppendCondition)
    end

    it "allows several leagues in the account, also for the same game type" do
      expect(call(name: "Foosball Spring")).to be_success
      expect(call(name: "Foosball Lunch")).to be_success
      expect(league_events.map { |event| event.data[:game_type] }).to eq(%w[Foosball Foosball])
    end
  end

  describe "concurrency conflict", :event_store do
    it "maps ConditionNotMet to a retry failure" do
      make_member
      allow(EventStore).to receive(:append).and_raise(DcbEventStore::ConditionNotMet)
      result = call
      expect(result).to eq(Result.failure("the account changed while you were working — please retry"))
    end
  end
end
