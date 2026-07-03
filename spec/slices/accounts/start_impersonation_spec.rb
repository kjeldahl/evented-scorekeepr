require "rails_helper"

RSpec.describe Accounts::StartImpersonation do
  def grant_super_admin(user_id)
    EventStore.append(Identity::Events.super_admin_granted(user_id:))
  end

  # Bob owns the account, so he is a member from creation.
  def account_with_member(owner_user_id: "bob-1")
    Accounts::CreateAccount.call(name: "Office", owner_user_id:).value
  end

  def call(super_admin_user_id: "root-1", account_id:, impersonated_user_id: "bob-1")
    described_class.call(super_admin_user_id:, account_id:, impersonated_user_id:)
  end

  def impersonation_events
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[ImpersonationStarted]) ])
    )
  end

  describe "super admin invariant", :event_store do
    it "rejects a non-super-admin actor" do
      result = call(super_admin_user_id: "alice-1", account_id: account_with_member)
      expect(result).to eq(Result.failure("only super admins can impersonate players"))
    end

    it "appends nothing for a non-super-admin actor" do
      call(super_admin_user_id: "alice-1", account_id: account_with_member)
      expect(impersonation_events).to be_empty
    end
  end

  describe "membership invariant", :event_store do
    it "rejects impersonating a non-member" do
      grant_super_admin("root-1")
      result = call(account_id: account_with_member, impersonated_user_id: "stranger-1")
      expect(result).to eq(Result.failure("only members can be impersonated"))
    end

    it "appends nothing when the target is not a member" do
      grant_super_admin("root-1")
      call(account_id: account_with_member, impersonated_user_id: "stranger-1")
      expect(impersonation_events).to be_empty
    end
  end

  describe "successful start", :event_store do
    before { grant_super_admin("root-1") }

    it "returns success with the new impersonation id" do
      result = call(account_id: account_with_member)
      expect(result).to be_success
      expect(result.value).to be_a(String)
    end

    it "appends an ImpersonationStarted event tying the super admin to the member" do
      account_id = account_with_member
      result = call(account_id:)
      event = impersonation_events.sole
      expect(event.data).to eq(
        impersonation_id: result.value, super_admin_user_id: "root-1",
        impersonated_user_id: "bob-1", account_id:
      )
    end

    it "appends with the decision model's append condition (concurrency guard)" do
      account_id = account_with_member
      condition = nil
      allow(EventStore).to receive(:append) { |_event, append_condition| condition = append_condition }
      call(account_id:)
      expect(condition).to be_a(DcbEventStore::AppendCondition)
    end

    it "generates a distinct impersonation id per start" do
      account_id = account_with_member
      expect(call(account_id:).value).not_to eq(call(account_id:).value)
    end
  end

  describe "concurrency conflict", :event_store do
    it "maps ConditionNotMet to a retry failure" do
      grant_super_admin("root-1")
      account_id = account_with_member
      allow(EventStore).to receive(:append).and_raise(DcbEventStore::ConditionNotMet)
      result = call(account_id:)
      expect(result).to eq(Result.failure("the account changed while you were working — please retry"))
    end
  end
end
