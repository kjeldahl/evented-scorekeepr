require "rails_helper"

RSpec.describe Scoreboards::Membership do
  def account_created(account_id: "acc-1", owner: "user-1")
    DcbEventStore::Event.new(
      type: "AccountCreated",
      data: { account_id:, name: "Office", owner_user_id: owner },
      tags: [ "account:#{account_id}", "user:#{owner}" ]
    )
  end

  def invitation_accepted(account_id: "acc-1", user_id: "user-2")
    DcbEventStore::Event.new(
      type: "InvitationAccepted",
      data: { invitation_id: "inv-1", account_id:, user_id: },
      tags: [ "invitation:inv-1", "account:#{account_id}", "user:#{user_id}" ]
    )
  end


  def member_left(account_id: "acc-1", user_id: "user-1")
    DcbEventStore::Event.new(
      type: "MemberLeft",
      data: { account_id:, user_id: },
      tags: [ "account:#{account_id}", "user:#{user_id}" ]
    )
  end

  describe ".projection" do
    subject(:projection) { described_class.projection(account_id: "acc-1", user_id: "user-1") }

    it "starts as not a member" do
      expect(projection.initial_state).to be(false)
    end

    it "treats the account owner as a member" do
      expect(projection.fold([ account_created ])).to be(true)
    end

    it "treats an accepted invitee as a member" do
      expect(projection.fold([ invitation_accepted(user_id: "user-1") ])).to be(true)
    end

    it "ends membership once a MemberLeft event is folded" do
      expect(projection.fold([ account_created, member_left ])).to be(false)
    end

    it "restores membership when an invitation is accepted after leaving" do
      events = [ account_created, member_left, invitation_accepted(user_id: "user-1") ]
      expect(projection.fold(events)).to be(true)
    end

    it "queries the membership event types tagged account and user" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[AccountCreated InvitationAccepted MemberLeft])
      expect(item.tags).to contain_exactly("account:acc-1", "user:user-1")
    end
  end

  describe ".member?", :event_store do
    it "is false for a stranger" do
      EventStore.append([ account_created ])
      expect(described_class.member?(account_id: "acc-1", user_id: "stranger")).to be(false)
    end

    it "is true for the owner" do
      EventStore.append([ account_created ])
      expect(described_class.member?(account_id: "acc-1", user_id: "user-1")).to be(true)
    end

    it "is true for an accepted invitee" do
      EventStore.append([ account_created, invitation_accepted ])
      expect(described_class.member?(account_id: "acc-1", user_id: "user-2")).to be(true)
    end

    it "grants nothing in another account (tenancy)" do
      EventStore.append([ account_created ])
      expect(described_class.member?(account_id: "acc-2", user_id: "user-1")).to be(false)
    end
  end
end
