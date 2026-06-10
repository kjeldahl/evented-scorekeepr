require "rails_helper"

RSpec.describe Accounts::AcceptInvitation do
  def create_account
    Accounts::CreateAccount.call(name: "Office", owner_user_id: "owner-1").value
  end

  def invite(account_id, email: "bob@example.com")
    Accounts::InvitePlayer.call(account_id:, email:, invited_by_user_id: "owner-1").value
  end

  def call(invitation_id:, user_id: "user-2", user_email: "bob@example.com")
    described_class.call(invitation_id:, user_id:, user_email:)
  end

  def accepted_events
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[InvitationAccepted]) ])
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
      expect(accepted_events).to be_empty
    end

    it "matches the email case-insensitively and ignoring whitespace" do
      invitation_id = invite(create_account)
      expect(call(invitation_id:, user_email: " BOB@Example.com ")).to be_success
    end
  end

  describe "successful acceptance", :event_store do
    it "returns success with the invitation's account id" do
      account_id = create_account
      result = call(invitation_id: invite(account_id))
      expect(result).to eq(Result.success(account_id))
    end

    it "appends an InvitationAccepted event tagged with invitation, account and user" do
      account_id = create_account
      invitation_id = invite(account_id)
      call(invitation_id:)
      event = accepted_events.sole
      expect(event.data).to eq(invitation_id:, account_id:, user_id: "user-2")
      expect(event.tags).to contain_exactly(
        "invitation:#{invitation_id}", "account:#{account_id}", "user:user-2"
      )
    end

    it "makes the accepting user a member of the account" do
      account_id = create_account
      call(invitation_id: invite(account_id))
      expect(Accounts::Membership.member?(account_id:, user_id: "user-2")).to be(true)
    end
  end

  describe "single acceptance", :event_store do
    it "rejects a second acceptance" do
      invitation_id = invite(create_account)
      call(invitation_id:)
      result = call(invitation_id:)
      expect(result).to eq(Result.failure("the invitation has already been accepted"))
    end

    it "appends nothing for a second acceptance" do
      invitation_id = invite(create_account)
      call(invitation_id:)
      expect { call(invitation_id:) }.not_to change { accepted_events.size }
    end

    it "maps a concurrent-accept ConditionNotMet to the already-accepted failure" do
      invitation_id = invite(create_account)
      allow(EventStore).to receive(:append).and_raise(DcbEventStore::ConditionNotMet)
      result = call(invitation_id:)
      expect(result).to eq(Result.failure("the invitation has already been accepted"))
    end
  end
end
