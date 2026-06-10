require "rails_helper"

RSpec.describe Accounts::PendingInvitations do
  def create_account(name: "Office")
    Accounts::CreateAccount.call(name:, owner_user_id: "owner-1").value
  end

  def invite(account_id, email: "bob@example.com")
    Accounts::InvitePlayer.call(account_id:, email:, invited_by_user_id: "owner-1").value
  end

  describe ".invitations_projection" do
    subject(:projection) { described_class.invitations_projection("bob@example.com") }

    it "starts with no invitations" do
      expect(projection.initial_state).to eq([])
    end

    it "collects PlayerInvited data in order" do
      first = Accounts::Events.player_invited(
        invitation_id: "inv-1", account_id: "acc-1", email: "bob@example.com", invited_by_user_id: "u1"
      )
      second = Accounts::Events.player_invited(
        invitation_id: "inv-2", account_id: "acc-2", email: "bob@example.com", invited_by_user_id: "u2"
      )
      expect(projection.fold([ first, second ]).map { |data| data[:invitation_id] }).to eq(%w[inv-1 inv-2])
    end

    it "queries PlayerInvited events tagged with the invitee email" do
      item = projection.query.items.sole
      expect(item.event_types).to eq([ "PlayerInvited" ])
      expect(item.tags).to eq([ "invitee_email:bob@example.com" ])
    end
  end

  describe ".for_email", :event_store do
    it "is empty when nobody invited that email" do
      expect(described_class.for_email("bob@example.com")).to eq([])
    end

    it "lists an open invitation with the account's name" do
      account_id = create_account
      invitation_id = invite(account_id)
      expect(described_class.for_email("bob@example.com")).to eq([
        described_class::PendingInvitation.new(
          invitation_id:, account_id:, account_name: "Office", email: "bob@example.com"
        )
      ])
    end

    it "normalises the looked-up email" do
      invitation_id = invite(create_account)
      expect(described_class.for_email(" BOB@Example.com ").map(&:invitation_id)).to eq([ invitation_id ])
    end

    it "excludes accepted invitations" do
      invitation_id = invite(create_account)
      Accounts::AcceptInvitation.call(invitation_id:, user_id: "user-2", user_email: "bob@example.com")
      expect(described_class.for_email("bob@example.com")).to eq([])
    end

    it "keeps other pending invitations when one is accepted" do
      accepted_id = invite(create_account)
      pending_id = invite(create_account(name: "Family"))
      Accounts::AcceptInvitation.call(invitation_id: accepted_id, user_id: "user-2", user_email: "bob@example.com")
      expect(described_class.for_email("bob@example.com").map(&:invitation_id)).to eq([ pending_id ])
    end

    it "does not list invitations sent to other emails" do
      invite(create_account, email: "carol@example.com")
      expect(described_class.for_email("bob@example.com")).to eq([])
    end
  end
end
