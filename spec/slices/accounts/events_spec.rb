require "rails_helper"

RSpec.describe Accounts::Events do
  describe ".account_created" do
    subject(:event) do
      described_class.account_created(account_id: "acc-1", name: "Office", owner_user_id: "user-1")
    end

    it "has the AccountCreated type" do
      expect(event.type).to eq("AccountCreated")
    end

    it "carries account_id, name and owner_user_id as data" do
      expect(event.data).to eq(account_id: "acc-1", name: "Office", owner_user_id: "user-1")
    end

    it "is tagged with the account id and the owner's user id" do
      expect(event.tags).to contain_exactly("account:acc-1", "user:user-1")
    end
  end

  describe ".player_invited" do
    subject(:event) do
      described_class.player_invited(
        invitation_id: "inv-1", account_id: "acc-1", email: " Bob@Example.COM ", invited_by_user_id: "user-1"
      )
    end

    it "has the PlayerInvited type" do
      expect(event.type).to eq("PlayerInvited")
    end

    it "carries invitation_id, account_id, normalised email and inviter as data" do
      expect(event.data).to eq(
        invitation_id: "inv-1", account_id: "acc-1", email: "bob@example.com", invited_by_user_id: "user-1"
      )
    end

    it "is tagged with the invitation, the account and the normalised invitee email" do
      expect(event.tags).to contain_exactly(
        "invitation:inv-1", "account:acc-1", "invitee_email:bob@example.com"
      )
    end
  end

  describe ".invitation_accepted" do
    subject(:event) do
      described_class.invitation_accepted(invitation_id: "inv-1", account_id: "acc-1", user_id: "user-2")
    end

    it "has the InvitationAccepted type" do
      expect(event.type).to eq("InvitationAccepted")
    end

    it "carries invitation_id, account_id and user_id as data" do
      expect(event.data).to eq(invitation_id: "inv-1", account_id: "acc-1", user_id: "user-2")
    end

    it "is tagged with the invitation, the account and the accepting user" do
      expect(event.tags).to contain_exactly("invitation:inv-1", "account:acc-1", "user:user-2")
    end
  end

  describe ".invitation_revoked" do
    subject(:event) do
      described_class.invitation_revoked(invitation_id: "inv-1", account_id: "acc-1", revoked_by_user_id: "user-1")
    end

    it "has the InvitationRevoked type" do
      expect(event.type).to eq("InvitationRevoked")
    end

    it "carries invitation_id, account_id and the revoking user as data" do
      expect(event.data).to eq(invitation_id: "inv-1", account_id: "acc-1", revoked_by_user_id: "user-1")
    end

    it "is tagged with the invitation and the account" do
      expect(event.tags).to contain_exactly("invitation:inv-1", "account:acc-1")
    end
  end

  describe ".invitation_declined" do
    subject(:event) do
      described_class.invitation_declined(invitation_id: "inv-1", account_id: "acc-1", user_id: "user-2")
    end

    it "has the InvitationDeclined type" do
      expect(event.type).to eq("InvitationDeclined")
    end

    it "carries invitation_id, account_id and user_id as data" do
      expect(event.data).to eq(invitation_id: "inv-1", account_id: "acc-1", user_id: "user-2")
    end

    it "is tagged with the invitation and the account" do
      expect(event.tags).to contain_exactly("invitation:inv-1", "account:acc-1")
    end
  end

  describe ".member_left" do
    subject(:event) { described_class.member_left(account_id: "acc-1", user_id: "user-2") }

    it "has the MemberLeft type" do
      expect(event.type).to eq("MemberLeft")
    end

    it "carries account_id and user_id as data" do
      expect(event.data).to eq(account_id: "acc-1", user_id: "user-2")
    end

    it "is tagged with the account and the departing user" do
      expect(event.tags).to contain_exactly("account:acc-1", "user:user-2")
    end
  end
end
