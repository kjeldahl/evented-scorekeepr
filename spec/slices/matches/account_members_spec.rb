require "rails_helper"

RSpec.describe Matches::AccountMembers do
  describe ".member_ids_projection" do
    subject(:projection) { described_class.member_ids_projection("acc-1") }

    it "starts with no members" do
      expect(projection.initial_state).to eq([])
    end

    it "collects the owner and accepted invitees, without duplicates" do
      created = DcbEventStore::Event.new(
        type: "AccountCreated",
        data: { account_id: "acc-1", name: "Office", owner_user_id: "user-1" },
        tags: [ "account:acc-1", "user:user-1" ]
      )
      accepted = DcbEventStore::Event.new(
        type: "InvitationAccepted",
        data: { invitation_id: "inv-1", account_id: "acc-1", user_id: "user-2" },
        tags: [ "invitation:inv-1", "account:acc-1", "user:user-2" ]
      )
      expect(projection.fold([ created, accepted, accepted ])).to eq(%w[user-1 user-2])
    end

    it "keeps already-folded members when AccountCreated arrives later (handlers accumulate)" do
      created = DcbEventStore::Event.new(
        type: "AccountCreated",
        data: { account_id: "acc-1", name: "Office", owner_user_id: "user-1" },
        tags: [ "account:acc-1", "user:user-1" ]
      )
      accepted = DcbEventStore::Event.new(
        type: "InvitationAccepted",
        data: { invitation_id: "inv-1", account_id: "acc-1", user_id: "user-2" },
        tags: [ "invitation:inv-1", "account:acc-1", "user:user-2" ]
      )
      expect(projection.fold([ accepted, created ])).to eq(%w[user-2 user-1])
    end

    it "queries both membership event types tagged with the account" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[AccountCreated InvitationAccepted])
      expect(item.tags).to eq([ "account:acc-1" ])
    end
  end

  describe ".user_name_projection" do
    subject(:projection) { described_class.user_name_projection("user-1") }

    it "starts with no name" do
      expect(projection.initial_state).to be_nil
    end

    it "folds the name from UserRegistered" do
      event = DcbEventStore::Event.new(
        type: "UserRegistered",
        data: { user_id: "user-1", name: "Alice", email: "alice@example.com", password_digest: "x" },
        tags: [ "user:user-1", "user_email:alice@example.com" ]
      )
      expect(projection.fold([ event ])).to eq("Alice")
    end

    it "queries UserRegistered events tagged with the user" do
      item = projection.query.items.sole
      expect(item.event_types).to eq([ "UserRegistered" ])
      expect(item.tags).to eq([ "user:user-1" ])
    end
  end

  describe ".for_account", :event_store do
    def register(name, email)
      Identity::RegisterUser.call(name:, email:, password: "secret123").value
    end

    it "lists the members sorted by name" do
      carol_id = register("Carol", "carol@example.com")
      account_id = Accounts::CreateAccount.call(name: "Office", owner_user_id: carol_id).value
      bob_id = register("Bob", "bob@example.com")
      invitation_id = Accounts::InvitePlayer.call(
        account_id:, email: "bob@example.com", invited_by_user_id: carol_id
      ).value
      Accounts::AcceptInvitation.call(invitation_id:, user_id: bob_id, user_email: "bob@example.com")

      expect(described_class.for_account(account_id)).to eq([
        described_class::Member.new(user_id: bob_id, name: "Bob"),
        described_class::Member.new(user_id: carol_id, name: "Carol")
      ])
    end

    it "lists nobody for an unknown account" do
      expect(described_class.for_account("missing")).to eq([])
    end
  end
end
