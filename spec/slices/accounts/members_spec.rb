require "rails_helper"

RSpec.describe Accounts::Members do
  describe ".member_ids_projection" do
    subject(:projection) { described_class.member_ids_projection("acc-1") }

    it "starts with no members" do
      expect(projection.initial_state).to eq([])
    end

    it "collects the owner and accepted invitees, without duplicates" do
      created = Accounts::Events.account_created(account_id: "acc-1", name: "Office", owner_user_id: "user-1")
      accepted = Accounts::Events.invitation_accepted(invitation_id: "inv-1", account_id: "acc-1", user_id: "user-2")
      expect(projection.fold([ created, accepted, accepted ])).to eq(%w[user-1 user-2])
    end

    it "keeps already-folded members when AccountCreated arrives later (handlers accumulate)" do
      created = Accounts::Events.account_created(account_id: "acc-1", name: "Office", owner_user_id: "user-1")
      accepted = Accounts::Events.invitation_accepted(invitation_id: "inv-1", account_id: "acc-1", user_id: "user-2")
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
    it "lists the owner with their registered name" do
      user_id = Identity::RegisterUser.call(name: "Alice", email: "alice@example.com", password: "secret123").value
      account_id = Accounts::CreateAccount.call(name: "Office", owner_user_id: user_id).value

      expect(described_class.for_account(account_id)).to eq(
        [ described_class::Member.new(user_id:, name: "Alice") ]
      )
    end

    it "lists members who accepted an invitation" do
      owner_id = Identity::RegisterUser.call(name: "Alice", email: "alice@example.com", password: "secret123").value
      bob_id = Identity::RegisterUser.call(name: "Bob", email: "bob@example.com", password: "secret123").value
      account_id = Accounts::CreateAccount.call(name: "Office", owner_user_id: owner_id).value
      invitation_id = Accounts::InvitePlayer.call(
        account_id:, email: "bob@example.com", invited_by_user_id: owner_id
      ).value
      Accounts::AcceptInvitation.call(invitation_id:, user_id: bob_id, user_email: "bob@example.com")

      expect(described_class.for_account(account_id).map(&:name)).to contain_exactly("Alice", "Bob")
    end
  end
end
