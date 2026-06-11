require "rails_helper"

RSpec.describe Accounts::AcceptInvitationOnBehalf do
  def create_account
    Accounts::CreateAccount.call(name: "Office", owner_user_id: "owner-1").value
  end

  def invite(account_id, email: "bob@example.com")
    Accounts::InvitePlayer.call(account_id:, email:, invited_by_user_id: "owner-1").value
  end

  # The identity slice owns UserRegistered; specs append the documented
  # event shape directly (the cross-slice contract from docs/DOMAIN.md).
  def register_user(user_id: "user-9", email: "bob@example.com")
    EventStore.append([ DcbEventStore::Event.new(
      type: "UserRegistered",
      data: { user_id:, name: "Bob", email:, password_digest: "x" },
      tags: [ "user:#{user_id}", "user_email:#{email}" ]
    ) ])
    user_id
  end

  def accepted_events
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[InvitationAccepted]) ])
    )
  end

  describe ".registered_user_id_projection" do
    subject(:projection) { described_class.registered_user_id_projection("bob@example.com") }

    it "starts with no user" do
      expect(projection.initial_state).to be_nil
    end

    it "folds the user id from UserRegistered" do
      event = DcbEventStore::Event.new(
        type: "UserRegistered",
        data: { user_id: "user-9", name: "Bob", email: "bob@example.com", password_digest: "x" },
        tags: [ "user:user-9", "user_email:bob@example.com" ]
      )
      expect(projection.fold([ event ])).to eq("user-9")
    end

    it "queries UserRegistered events tagged with the email" do
      item = projection.query.items.sole
      expect(item.event_types).to eq([ "UserRegistered" ])
      expect(item.tags).to eq([ "user_email:bob@example.com" ])
    end
  end

  describe "unknown invitation", :event_store do
    it "rejects an invitation id that was never issued" do
      expect(described_class.call(invitation_id: "missing")).to eq(Result.failure("the invitation was not found"))
    end
  end

  describe "unregistered invitee", :event_store do
    it "rejects when nobody registered with the invitation's email" do
      invitation_id = invite(create_account)
      result = described_class.call(invitation_id:)
      expect(result).to eq(Result.failure("the invited player has not registered yet"))
    end

    it "does not count a user registered with a different email" do
      invitation_id = invite(create_account)
      register_user(email: "carol@example.com")
      result = described_class.call(invitation_id:)
      expect(result).to eq(Result.failure("the invited player has not registered yet"))
    end

    it "appends nothing when the invitee is not registered" do
      invitation_id = invite(create_account)
      described_class.call(invitation_id:)
      expect(accepted_events).to be_empty
    end
  end

  describe "successful acceptance on behalf", :event_store do
    it "returns success with the invitation's account id" do
      account_id = create_account
      invitation_id = invite(account_id)
      register_user
      expect(described_class.call(invitation_id:)).to eq(Result.success(account_id))
    end

    it "appends an InvitationAccepted event for the registered user" do
      account_id = create_account
      invitation_id = invite(account_id)
      register_user(user_id: "user-9")
      described_class.call(invitation_id:)
      event = accepted_events.sole
      expect(event.data).to eq(invitation_id:, account_id:, user_id: "user-9")
      expect(event.tags).to contain_exactly(
        "invitation:#{invitation_id}", "account:#{account_id}", "user:user-9"
      )
    end

    it "makes the invited player a member of the account" do
      account_id = create_account
      invitation_id = invite(account_id)
      register_user(user_id: "user-9")
      described_class.call(invitation_id:)
      expect(Accounts::Membership.member?(account_id:, user_id: "user-9")).to be(true)
    end
  end

  describe "single acceptance", :event_store do
    it "rejects accepting on behalf twice (delegates the invariant to AcceptInvitation)" do
      invitation_id = invite(create_account)
      register_user
      described_class.call(invitation_id:)
      result = described_class.call(invitation_id:)
      expect(result).to eq(Result.failure("the invitation has already been accepted"))
    end
  end
end
