require "rails_helper"

RSpec.describe Identity::GrantSuperAdmin do
  def register(user_id: "user-1")
    EventStore.append(
      Identity::Events.user_registered(
        user_id:, name: "Root", email: "#{user_id}@example.com", password_digest: "digest-1"
      )
    )
  end

  def grants
    query = DcbEventStore::Query.new(DcbEventStore::QueryItem.new(event_types: %w[SuperAdminGranted]))
    EventStore.read(query)
  end

  def stored_events
    EventStore.read(DcbEventStore::Query.all)
  end

  describe "unknown user", :event_store do
    it "rejects a user id that was never registered" do
      expect(described_class.call(user_id: "ghost")).to eq(Result.failure("the user was not found"))
    end

    it "appends nothing for an unknown user" do
      described_class.call(user_id: "ghost")
      expect(stored_events).to be_empty
    end
  end

  describe "first grant", :event_store do
    before { register }

    it "returns success with the user id" do
      expect(described_class.call(user_id: "user-1")).to eq(Result.success("user-1"))
    end

    it "appends a SuperAdminGranted event with the user id as data and tag" do
      described_class.call(user_id: "user-1")
      event = grants.sole
      expect(event.type).to eq("SuperAdminGranted")
      expect(event.data).to eq(user_id: "user-1")
      expect(event.tags).to eq([ "user:user-1", "super_admin" ])
    end
  end

  describe "idempotency", :event_store do
    before do
      register
      described_class.call(user_id: "user-1")
    end

    it "succeeds when the user is already a super admin" do
      expect(described_class.call(user_id: "user-1")).to eq(Result.success("user-1"))
    end

    it "appends nothing for an existing super admin" do
      expect { described_class.call(user_id: "user-1") }.not_to change { grants.size }
    end
  end

  describe "a second, different user", :event_store do
    before do
      register
      register(user_id: "user-2")
      described_class.call(user_id: "user-1")
    end

    it "is rejected" do
      expect(described_class.call(user_id: "user-2")).to eq(Result.failure("there can only be one super admin"))
    end

    it "appends nothing" do
      expect { described_class.call(user_id: "user-2") }.not_to change { grants.size }
    end
  end

  describe "concurrency conflict", :event_store do
    before do
      register
      register(user_id: "user-2")
    end

    it "retries after ConditionNotMet and succeeds when the winner was the same user" do
      calls = 0
      allow(EventStore).to receive(:append).and_wrap_original do |original, *args|
        calls += 1
        calls == 1 ? raise(DcbEventStore::ConditionNotMet) : original.call(*args)
      end
      expect(described_class.call(user_id: "user-1")).to eq(Result.success("user-1"))
      expect(grants.count).to eq(1)
    end

    it "rejects a different user whose grant lost the race to another user" do
      stale_decision = EventStore.decide(
        user: Identity::UserExistence.projection(user_id: "user-2"),
        super_admin: Identity::SuperAdminStatus.projection
      )
      described_class.call(user_id: "user-1") # the concurrent grant wins the race
      allow(EventStore).to receive(:decide).and_return(stale_decision, EventStore.decide(
        user: Identity::UserExistence.projection(user_id: "user-2"),
        super_admin: Identity::SuperAdminStatus.projection
      ))
      expect(described_class.call(user_id: "user-2")).to eq(Result.failure("there can only be one super admin"))
      expect(grants.count).to eq(1)
    end

    it "loses a same-user race without a second append" do
      stale_decision = EventStore.decide(
        user: Identity::UserExistence.projection(user_id: "user-1"),
        super_admin: Identity::SuperAdminStatus.projection
      )
      described_class.call(user_id: "user-1")
      fresh = EventStore.decide(
        user: Identity::UserExistence.projection(user_id: "user-1"),
        super_admin: Identity::SuperAdminStatus.projection
      )
      allow(EventStore).to receive(:decide).and_return(stale_decision, fresh)
      expect(described_class.call(user_id: "user-1")).to eq(Result.success("user-1"))
      expect(grants.count).to eq(1)
    end
  end
end
