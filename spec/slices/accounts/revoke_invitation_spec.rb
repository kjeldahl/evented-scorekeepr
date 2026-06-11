require "rails_helper"

RSpec.describe Accounts::RevokeInvitation do
  def create_account
    Accounts::CreateAccount.call(name: "Office", owner_user_id: "owner-1").value
  end

  def invite(account_id, email: "bob@example.com")
    Accounts::InvitePlayer.call(account_id:, email:, invited_by_user_id: "owner-1").value
  end

  def call(invitation_id:, account_id:, user_id: "owner-1")
    described_class.call(invitation_id:, account_id:, user_id:)
  end

  def revoked_events
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[InvitationRevoked]) ])
    )
  end

  describe "membership invariant", :event_store do
    it "rejects a non-member" do
      account_id = create_account
      invitation_id = invite(account_id)
      result = call(invitation_id:, account_id:, user_id: "stranger")
      expect(result).to eq(Result.failure("only members can revoke invitations"))
    end

    it "appends nothing for a non-member" do
      account_id = create_account
      call(invitation_id: invite(account_id), account_id:, user_id: "stranger")
      expect(revoked_events).to be_empty
    end
  end

  describe "unknown invitation", :event_store do
    it "rejects an invitation id that was never issued" do
      account_id = create_account
      result = call(invitation_id: "missing", account_id:)
      expect(result).to eq(Result.failure("the invitation was not found"))
    end

    it "rejects an invitation that belongs to a different account" do
      account_id = create_account
      other_account = Accounts::CreateAccount.call(name: "Family", owner_user_id: "owner-1").value
      invitation_id = invite(other_account)
      result = call(invitation_id:, account_id:)
      expect(result).to eq(Result.failure("the invitation was not found"))
    end
  end

  describe "successful revocation", :event_store do
    it "returns success with the invitation id" do
      account_id = create_account
      invitation_id = invite(account_id)
      expect(call(invitation_id:, account_id:)).to eq(Result.success(invitation_id))
    end

    it "appends an InvitationRevoked event tagged with invitation and account" do
      account_id = create_account
      invitation_id = invite(account_id)
      call(invitation_id:, account_id:)
      event = revoked_events.sole
      expect(event.data).to eq(invitation_id:, account_id:, revoked_by_user_id: "owner-1")
      expect(event.tags).to contain_exactly("invitation:#{invitation_id}", "account:#{account_id}")
    end

    it "removes the invitation from the invitee's pending list" do
      account_id = create_account
      call(invitation_id: invite(account_id), account_id:)
      expect(Accounts::PendingInvitations.for_email("bob@example.com")).to eq([])
    end
  end

  describe "settled invitations", :event_store do
    it "rejects revoking an accepted invitation" do
      account_id = create_account
      invitation_id = invite(account_id)
      Accounts::AcceptInvitation.call(invitation_id:, user_id: "user-2", user_email: "bob@example.com")
      result = call(invitation_id:, account_id:)
      expect(result).to eq(Result.failure("the invitation is no longer pending"))
    end

    it "rejects revoking twice" do
      account_id = create_account
      invitation_id = invite(account_id)
      call(invitation_id:, account_id:)
      result = call(invitation_id:, account_id:)
      expect(result).to eq(Result.failure("the invitation is no longer pending"))
    end

    it "appends nothing for a settled invitation" do
      account_id = create_account
      invitation_id = invite(account_id)
      call(invitation_id:, account_id:)
      expect { call(invitation_id:, account_id:) }.not_to change { revoked_events.size }
    end

    it "loses the race against an accept that lands after the decision was read" do
      account_id = create_account
      invitation_id = invite(account_id)
      stale_decision = EventStore.decide(
        invitation: Accounts::InvitationState.projection(invitation_id),
        member: Accounts::Membership.projection(account_id:, user_id: "owner-1")
      )
      Accounts::AcceptInvitation.call(invitation_id:, user_id: "user-2", user_email: "bob@example.com")
      allow(EventStore).to receive(:decide).and_return(stale_decision)
      result = call(invitation_id:, account_id:)
      expect(result).to eq(Result.failure("the invitation is no longer pending"))
      expect(revoked_events).to be_empty
    end
  end
end
