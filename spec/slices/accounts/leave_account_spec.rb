require "rails_helper"

RSpec.describe Accounts::LeaveAccount do
  def create_account(owner_user_id: "owner-1")
    Accounts::CreateAccount.call(name: "Office", owner_user_id:).value
  end

  def join(account_id, user_id:, email: "bob@example.com")
    invitation_id = Accounts::InvitePlayer.call(account_id:, email:, invited_by_user_id: "owner-1").value
    Accounts::AcceptInvitation.call(invitation_id:, user_id:, user_email: email)
  end

  def left_events
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[MemberLeft]) ])
    )
  end

  describe "membership invariant", :event_store do
    it "rejects a user who is not a member" do
      account_id = create_account
      result = described_class.call(account_id:, user_id: "stranger")
      expect(result).to eq(Result.failure("only members can leave an account"))
    end

    it "rejects leaving twice" do
      account_id = create_account
      join(account_id, user_id: "user-2")
      described_class.call(account_id:, user_id: "user-2")
      result = described_class.call(account_id:, user_id: "user-2")
      expect(result).to eq(Result.failure("only members can leave an account"))
    end

    it "appends nothing for a non-member" do
      account_id = create_account
      described_class.call(account_id:, user_id: "stranger")
      expect(left_events).to be_empty
    end
  end

  describe "a member leaves", :event_store do
    it "returns success with the account id" do
      account_id = create_account
      join(account_id, user_id: "user-2")
      expect(described_class.call(account_id:, user_id: "user-2")).to eq(Result.success(account_id))
    end

    it "appends a MemberLeft event tagged with account and user" do
      account_id = create_account
      join(account_id, user_id: "user-2")
      described_class.call(account_id:, user_id: "user-2")
      event = left_events.sole
      expect(event.data).to eq(account_id:, user_id: "user-2")
      expect(event.tags).to contain_exactly("account:#{account_id}", "user:user-2")
    end

    it "ends the membership" do
      account_id = create_account
      join(account_id, user_id: "user-2")
      described_class.call(account_id:, user_id: "user-2")
      expect(Accounts::Membership.member?(account_id:, user_id: "user-2")).to be(false)
    end

    it "lets the owner leave too" do
      account_id = create_account(owner_user_id: "owner-1")
      expect(described_class.call(account_id:, user_id: "owner-1")).to be_success
      expect(Accounts::Membership.member?(account_id:, user_id: "owner-1")).to be(false)
    end

    it "allows rejoining via a fresh invitation" do
      account_id = create_account
      join(account_id, user_id: "user-2")
      described_class.call(account_id:, user_id: "user-2")
      join(account_id, user_id: "user-2")
      expect(Accounts::Membership.member?(account_id:, user_id: "user-2")).to be(true)
    end

    it "loses the race against a concurrent leave" do
      account_id = create_account
      join(account_id, user_id: "user-2")
      stale_decision = EventStore.decide(
        member: Accounts::Membership.projection(account_id:, user_id: "user-2")
      )
      described_class.call(account_id:, user_id: "user-2")
      allow(EventStore).to receive(:decide).and_return(stale_decision)
      result = described_class.call(account_id:, user_id: "user-2")
      expect(result).to eq(Result.failure("the account changed while you were working — please retry"))
      expect(left_events.count).to eq(1)
    end
  end
end
