require "rails_helper"

RSpec.describe Accounts::Membership do
  describe ".projection" do
    subject(:projection) { described_class.projection(account_id: "acc-1", user_id: "user-1") }

    it "starts as not a member" do
      expect(projection.initial_state).to be(false)
    end

    it "is a member once an AccountCreated event is folded (the owner)" do
      event = Accounts::Events.account_created(account_id: "acc-1", name: "Office", owner_user_id: "user-1")
      expect(projection.fold([ event ])).to be(true)
    end

    it "is a member once an InvitationAccepted event is folded" do
      event = Accounts::Events.invitation_accepted(invitation_id: "inv-1", account_id: "acc-1", user_id: "user-1")
      expect(projection.fold([ event ])).to be(true)
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
      account_id = Accounts::CreateAccount.call(name: "Office", owner_user_id: "user-1").value
      expect(described_class.member?(account_id:, user_id: "user-1")).to be(true)
    end

    it "is false for the owner of a different account" do
      Accounts::CreateAccount.call(name: "Office", owner_user_id: "user-1")
      other = Accounts::CreateAccount.call(name: "Family", owner_user_id: "user-2").value
      expect(described_class.member?(account_id: other, user_id: "user-1")).to be(false)
    end
  end
end
