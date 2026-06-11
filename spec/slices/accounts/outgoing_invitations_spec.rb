require "rails_helper"

RSpec.describe Accounts::OutgoingInvitations do
  def invited(invitation_id:, email:, account_id: "acc-1")
    Accounts::Events.player_invited(invitation_id:, account_id:, email:, invited_by_user_id: "owner-1")
  end

  def accepted(invitation_id:, account_id: "acc-1")
    Accounts::Events.invitation_accepted(invitation_id:, account_id:, user_id: "user-2")
  end

  def outgoing(invitation_id:, email:)
    described_class::OutgoingInvitation.new(invitation_id:, email:)
  end

  describe ".projection" do
    subject(:projection) { described_class.projection("acc-1") }

    it "starts with no invitations" do
      expect(projection.initial_state).to eq({})
    end

    it "collects pending invitations keyed by invitation id, in order" do
      state = projection.fold([
        invited(invitation_id: "inv-1", email: "bob@example.com"),
        invited(invitation_id: "inv-2", email: "carol@example.com")
      ])
      expect(state).to eq(
        "inv-1" => outgoing(invitation_id: "inv-1", email: "bob@example.com"),
        "inv-2" => outgoing(invitation_id: "inv-2", email: "carol@example.com")
      )
    end

    it "removes an invitation once it is accepted" do
      state = projection.fold([
        invited(invitation_id: "inv-1", email: "bob@example.com"),
        accepted(invitation_id: "inv-1")
      ])
      expect(state).to eq({})
    end

    it "keeps the other invitations when one is accepted" do
      state = projection.fold([
        invited(invitation_id: "inv-1", email: "bob@example.com"),
        invited(invitation_id: "inv-2", email: "carol@example.com"),
        accepted(invitation_id: "inv-1")
      ])
      expect(state).to eq("inv-2" => outgoing(invitation_id: "inv-2", email: "carol@example.com"))
    end

    it "ignores an acceptance for an unknown invitation" do
      expect(projection.fold([ accepted(invitation_id: "inv-ghost") ])).to eq({})
    end

    it "queries both invitation event types tagged with the account" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[PlayerInvited InvitationAccepted])
      expect(item.tags).to eq([ "account:acc-1" ])
    end
  end

  describe ".pending" do
    it "maps the invitation id to an OutgoingInvitation carrying the email" do
      entry = described_class.pending(invited(invitation_id: "inv-1", email: "bob@example.com"))
      expect(entry).to eq("inv-1" => outgoing(invitation_id: "inv-1", email: "bob@example.com"))
    end
  end

  describe ".for_account", :event_store do
    def create_account(name: "Office")
      Accounts::CreateAccount.call(name:, owner_user_id: "owner-1").value
    end

    def invite_into(account_id, email: "bob@example.com")
      Accounts::InvitePlayer.call(account_id:, email:, invited_by_user_id: "owner-1").value
    end

    it "is empty when nobody was invited" do
      expect(described_class.for_account(create_account)).to eq([])
    end

    it "lists pending invitations in the order they were sent" do
      account_id = create_account
      first = invite_into(account_id, email: "bob@example.com")
      second = invite_into(account_id, email: "carol@example.com")
      expect(described_class.for_account(account_id)).to eq([
        outgoing(invitation_id: first, email: "bob@example.com"),
        outgoing(invitation_id: second, email: "carol@example.com")
      ])
    end

    it "excludes accepted invitations" do
      account_id = create_account
      invitation_id = invite_into(account_id)
      Accounts::AcceptInvitation.call(invitation_id:, user_id: "user-2", user_email: "bob@example.com")
      expect(described_class.for_account(account_id)).to eq([])
    end

    it "does not list other accounts' invitations" do
      account_id = create_account
      invite_into(create_account(name: "Family"), email: "carol@example.com")
      expect(described_class.for_account(account_id)).to eq([])
    end
  end
end
