require "rails_helper"

# The leagues slice folds the accounts slice's membership events itself;
# events are the only cross-slice contract, so the spec builds them raw
# (type/data/tags per docs/DOMAIN.md) instead of using accounts classes.
RSpec.describe Leagues::Membership do
  def account_created(account_id: "acc-1", user_id: "user-1")
    DcbEventStore::Event.new(
      type: "AccountCreated",
      data: { account_id:, name: "Office", owner_user_id: user_id },
      tags: [ "account:#{account_id}", "user:#{user_id}" ]
    )
  end

  def invitation_accepted(account_id: "acc-1", user_id: "user-1")
    DcbEventStore::Event.new(
      type: "InvitationAccepted",
      data: { invitation_id: "inv-1", account_id:, user_id: },
      tags: [ "invitation:inv-1", "account:#{account_id}", "user:#{user_id}" ]
    )
  end

  describe ".projection" do
    subject(:projection) { described_class.projection(account_id: "acc-1", user_id: "user-1") }

    it "starts as not a member" do
      expect(projection.initial_state).to be(false)
    end

    it "is a member once an AccountCreated event is folded (the owner)" do
      expect(projection.fold([ account_created ])).to be(true)
    end

    it "is a member once an InvitationAccepted event is folded" do
      expect(projection.fold([ invitation_accepted ])).to be(true)
    end

    it "queries both membership event types with the account and user tags" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[AccountCreated InvitationAccepted])
      expect(item.tags).to contain_exactly("account:acc-1", "user:user-1")
    end
  end

  describe ".member?", :event_store do
    it "is false when no membership events exist" do
      expect(described_class.member?(account_id: "acc-1", user_id: "user-1")).to be(false)
    end

    it "is true for the account owner" do
      EventStore.append([ account_created ])
      expect(described_class.member?(account_id: "acc-1", user_id: "user-1")).to be(true)
    end

    it "is true for a user who accepted an invitation" do
      EventStore.append([ invitation_accepted(user_id: "user-2") ])
      expect(described_class.member?(account_id: "acc-1", user_id: "user-2")).to be(true)
    end

    it "is false for a member of a different account" do
      EventStore.append([ account_created(account_id: "acc-2") ])
      expect(described_class.member?(account_id: "acc-1", user_id: "user-1")).to be(false)
    end

    it "is false for a different user of the same account" do
      EventStore.append([ account_created ])
      expect(described_class.member?(account_id: "acc-1", user_id: "user-2")).to be(false)
    end
  end
end
