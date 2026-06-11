require "rails_helper"

RSpec.describe Identity::GrantSuperAdmin do
  def register(user_id: "user-1")
    EventStore.append(
      Identity::Events.user_registered(
        user_id:, name: "Root", email: "root@example.com", password_digest: "digest-1"
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
      expect(event.tags).to eq([ "user:user-1" ])
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

  describe "concurrency conflict", :event_store do
    before { register }

    it "maps ConditionNotMet to success (only an identical grant can trip it)" do
      allow(EventStore).to receive(:append).and_raise(DcbEventStore::ConditionNotMet)
      expect(described_class.call(user_id: "user-1")).to eq(Result.success("user-1"))
    end

    it "loses the race against a grant that lands after the decision was read, without a second append" do
      stale_decision = EventStore.decide(
        user: Identity::UserExistence.projection(user_id: "user-1"),
        super_admin: Identity::SuperAdminStatus.projection(user_id: "user-1")
      )
      described_class.call(user_id: "user-1") # the concurrent grant wins the race
      allow(EventStore).to receive(:decide).and_return(stale_decision)
      expect(described_class.call(user_id: "user-1")).to eq(Result.success("user-1"))
      expect(grants.count).to eq(1)
    end
  end
end
