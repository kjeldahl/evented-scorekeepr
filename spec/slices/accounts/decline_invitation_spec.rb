require "rails_helper"

RSpec.describe Accounts::DeclineInvitation do
  def create_account
    Accounts::CreateAccount.call(name: "Office", owner_user_id: "owner-1").value
  end

  def invite(account_id, email: "bob@example.com")
    Accounts::InvitePlayer.call(account_id:, email:, invited_by_user_id: "owner-1").value
  end

  def call(invitation_id:, user_id: "user-2", user_email: "bob@example.com")
    described_class.call(invitation_id:, user_id:, user_email:)
  end

  def declined_events
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[InvitationDeclined]) ])
    )
  end

  describe "unknown invitation", :event_store do
    it "rejects an invitation id that was never issued" do
      expect(call(invitation_id: "missing")).to eq(Result.failure("the invitation was not found"))
    end
  end

  describe "email invariant", :event_store do
    it "rejects a user whose email does not match the invitation" do
      invitation_id = invite(create_account)
      result = call(invitation_id:, user_email: "carol@example.com")
      expect(result).to eq(Result.failure("the invitation was not sent to this user's email"))
    end

    it "appends nothing for a mismatched email" do
      invitation_id = invite(create_account)
      call(invitation_id:, user_email: "carol@example.com")
      expect(declined_events).to be_empty
    end

    it "matches the email case-insensitively and ignoring whitespace" do
      invitation_id = invite(create_account)
      expect(call(invitation_id:, user_email: " BOB@Example.com ")).to be_success
    end

    it "rejects a user without an email instead of raising" do
      invitation_id = invite(create_account)
      result = call(invitation_id:, user_email: nil)
      expect(result).to eq(Result.failure("the invitation was not sent to this user's email"))
    end
  end

  describe "successful decline", :event_store do
    it "returns success with the invitation's account id" do
      account_id = create_account
      expect(call(invitation_id: invite(account_id))).to eq(Result.success(account_id))
    end

    it "appends an InvitationDeclined event tagged with invitation and account" do
      account_id = create_account
      invitation_id = invite(account_id)
      call(invitation_id:)
      event = declined_events.sole
      expect(event.data).to eq(invitation_id:, account_id:, user_id: "user-2")
      expect(event.tags).to contain_exactly("invitation:#{invitation_id}", "account:#{account_id}")
    end

    it "does not make the declining user a member" do
      account_id = create_account
      call(invitation_id: invite(account_id))
      expect(Accounts::Membership.member?(account_id:, user_id: "user-2")).to be(false)
    end

    it "removes the invitation from the invitee's pending list" do
      call(invitation_id: invite(create_account))
      expect(Accounts::PendingInvitations.for_email("bob@example.com")).to eq([])
    end
  end

  describe "settled invitations", :event_store do
    it "rejects declining an accepted invitation" do
      invitation_id = invite(create_account)
      Accounts::AcceptInvitation.call(invitation_id:, user_id: "user-2", user_email: "bob@example.com")
      expect(call(invitation_id:)).to eq(Result.failure("the invitation is no longer pending"))
    end

    it "rejects declining twice" do
      invitation_id = invite(create_account)
      call(invitation_id:)
      expect(call(invitation_id:)).to eq(Result.failure("the invitation is no longer pending"))
    end

    it "appends nothing for a settled invitation" do
      invitation_id = invite(create_account)
      call(invitation_id:)
      expect { call(invitation_id:) }.not_to change { declined_events.size }
    end

    it "loses the race against an accept that lands after the decision was read" do
      invitation_id = invite(create_account)
      stale_decision = EventStore.decide(invitation: Accounts::InvitationState.projection(invitation_id))
      Accounts::AcceptInvitation.call(invitation_id:, user_id: "user-2", user_email: "bob@example.com")
      allow(EventStore).to receive(:decide).and_return(stale_decision)
      result = call(invitation_id:)
      expect(result).to eq(Result.failure("the invitation is no longer pending"))
      expect(declined_events).to be_empty
    end
  end
end
