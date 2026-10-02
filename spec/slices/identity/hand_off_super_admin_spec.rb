require "rails_helper"

RSpec.describe Identity::HandOffSuperAdmin, :event_store do
  def register(user_id, password: "secret123")
    result = Identity::RegisterUser.call(name: user_id, email: "#{user_id}@example.com", password:)
    # RegisterUser mints ids itself; map the minted id back to the label.
    ids[user_id] = result.value
  end

  def ids
    @ids ||= {}
  end

  def types
    EventStore.read(DcbEventStore::Query.all).map(&:type)
  end

  def handoffs
    EventStore.read(DcbEventStore::Query.new(DcbEventStore::QueryItem.new(event_types: "SuperAdminHandedOff")))
  end

  def hand_off(from: "root", to: "alice", reauthenticated: true, email: nil, impersonation_id: nil)
    described_class.call(from_user_id: ids.fetch(from), reauthenticated:, to_email: email || "#{to}@example.com", impersonation_id:)
  end

  def current
    EventStore.project(Identity::CurrentSuperAdmin.projection)
  end

  before do
    %w[root alice bob].each { |label| register(label) }
    Identity::GrantSuperAdmin.call(user_id: ids.fetch("root"))
  end

  it "hands status to the recipient and returns their id" do
    expect(hand_off).to eq(Result.success(ids.fetch("alice")))
    expect(current).to eq(ids.fetch("alice"))
  end

  it "appends one SuperAdminHandedOff event with both ids" do
    hand_off
    expect(handoffs.sole.data).to eq(from_user_id: ids.fetch("root"), to_user_id: ids.fetch("alice"))
  end

  it "normalises the recipient email" do
    expect(hand_off(email: "  ALICE@Example.com ")).to eq(Result.success(ids.fetch("alice")))
  end

  it "lets the new super admin hand off again" do
    hand_off
    hand_off(from: "alice", to: "bob")
    expect(current).to eq(ids.fetch("bob"))
  end

  it "rejects the former super admin" do
    hand_off
    expect(hand_off(to: "bob")).to eq(Result.failure("only the super admin can hand off super admin status"))
  end

  it "rejects an ordinary user and appends nothing" do
    expect(hand_off(from: "alice", to: "bob")).to eq(Result.failure(described_class::NOT_SUPER_ADMIN))
    expect(handoffs).to be_empty
  end

  it "checks the sender before re-authentication" do
    expect(hand_off(from: "alice", reauthenticated: false)).to eq(Result.failure(described_class::NOT_SUPER_ADMIN))
  end

  it "rejects a failed re-authentication and appends nothing" do
    expect(hand_off(reauthenticated: false)).to eq(Result.failure("invalid credentials"))
    expect(handoffs).to be_empty
  end

  it "checks re-authentication before the recipient" do
    expect(hand_off(reauthenticated: false, email: "nobody@example.com")).to eq(Result.failure("invalid credentials"))
  end

  it "rejects an unknown recipient and appends nothing" do
    expect(hand_off(email: "nobody@example.com")).to eq(Result.failure("the user was not found"))
    expect(handoffs).to be_empty
  end

  it "rejects handing off to oneself and appends nothing" do
    expect(hand_off(to: "root")).to eq(Result.failure("you are already the super admin"))
    expect(handoffs).to be_empty
    expect(current).to eq(ids.fetch("root"))
  end

  it "checks the recipient exists before the self check" do
    expect(hand_off(email: "nobody@example.com")).to eq(Result.failure("the user was not found"))
  end

  it "appends no impersonation end when none is given" do
    hand_off
    expect(types).not_to include("ImpersonationEnded")
  end

  it "ends the given impersonation in the same write" do
    hand_off(impersonation_id: "imp-1")
    expect(types).to include("SuperAdminHandedOff")
    ended = EventStore.read(DcbEventStore::Query.new(DcbEventStore::QueryItem.new(event_types: "ImpersonationEnded"))).sole
    expect(ended.data).to eq(impersonation_id: "imp-1", super_admin_user_id: ids.fetch("root"))
  end

  it "retries after a concurrent change and then reports the new state" do
    calls = 0
    allow(EventStore).to receive(:append).and_wrap_original do |original, *args|
      calls += 1
      calls == 1 ? raise(DcbEventStore::ConditionNotMet) : original.call(*args)
    end
    expect(hand_off).to eq(Result.success(ids.fetch("alice")))
    expect(calls).to eq(2)
  end

  it "does not end the impersonation when rejecting a self-handoff" do
    hand_off(to: "root", impersonation_id: "imp-1")
    expect(types).not_to include("ImpersonationEnded")
  end

  it "keeps the impersonation end when retrying" do
    calls = 0
    allow(EventStore).to receive(:append).and_wrap_original do |original, *args|
      calls += 1
      calls == 1 ? raise(DcbEventStore::ConditionNotMet) : original.call(*args)
    end
    hand_off(impersonation_id: "imp-1")
    expect(types).to include("ImpersonationEnded")
  end

  it "rejects when a concurrent handoff lands between decision and append" do
    raced = false
    allow(EventStore).to receive(:append).and_wrap_original do |original, *args|
      unless raced
        raced = true
        original.call(Identity::Events.super_admin_handed_off(from_user_id: ids.fetch("root"), to_user_id: ids.fetch("bob")))
      end
      original.call(*args)
    end
    expect(hand_off).to eq(Result.failure(described_class::NOT_SUPER_ADMIN))
    expect(current).to eq(ids.fetch("bob"))
  end

  it "reports a missing email as an unknown user" do
    expect(described_class.call(from_user_id: ids.fetch("root"), reauthenticated: true, to_email: nil, impersonation_id: nil))
      .to eq(Result.failure("the user was not found"))
  end
end
