require "rails_helper"

RSpec.describe Accounts::MyAccounts do
  describe ".account_ids_projection" do
    subject(:projection) { described_class.account_ids_projection("user-1") }

    it "starts with no accounts" do
      expect(projection.initial_state).to eq([])
    end

    it "collects accounts the user created and was accepted into, without duplicates" do
      created = Accounts::Events.account_created(account_id: "acc-1", name: "Office", owner_user_id: "user-1")
      accepted = Accounts::Events.invitation_accepted(invitation_id: "inv-1", account_id: "acc-2", user_id: "user-1")
      expect(projection.fold([ created, accepted, created ])).to eq(%w[acc-1 acc-2])
    end

    it "queries both membership event types tagged with the user" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[AccountCreated InvitationAccepted])
      expect(item.tags).to eq([ "user:user-1" ])
    end
  end

  describe ".for_user", :event_store do
    it "is empty for a user who belongs to no account" do
      expect(described_class.for_user("user-1")).to eq([])
    end

    it "lists owned accounts with their names" do
      account_id = Accounts::CreateAccount.call(name: "Office", owner_user_id: "user-1").value
      expect(described_class.for_user("user-1").map { |a| [ a.id, a.name ] }).to eq([ [ account_id, "Office" ] ])
    end

    it "lists accounts joined by accepting an invitation" do
      account_id = Accounts::CreateAccount.call(name: "Office", owner_user_id: "owner-1").value
      invitation_id = Accounts::InvitePlayer.call(
        account_id:, email: "bob@example.com", invited_by_user_id: "owner-1"
      ).value
      Accounts::AcceptInvitation.call(invitation_id:, user_id: "user-2", user_email: "bob@example.com")

      expect(described_class.for_user("user-2").map(&:id)).to eq([ account_id ])
    end

    it "does not list other users' accounts" do
      Accounts::CreateAccount.call(name: "Office", owner_user_id: "owner-1")
      expect(described_class.for_user("user-2")).to eq([])
    end
  end
end
