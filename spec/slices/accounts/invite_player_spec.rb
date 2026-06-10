require "rails_helper"

RSpec.describe Accounts::InvitePlayer do
  def create_account(owner_user_id: "owner-1")
    Accounts::CreateAccount.call(name: "Office", owner_user_id:).value
  end

  def call(account_id:, email: "bob@example.com", invited_by_user_id: "owner-1")
    described_class.call(account_id:, email:, invited_by_user_id:)
  end

  def invitation_events
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[PlayerInvited]) ])
    )
  end

  describe "validation", :event_store do
    it "rejects a blank email" do
      expect(call(account_id: create_account, email: "  ")).to eq(Result.failure("email is required"))
    end

    it "rejects a nil email" do
      expect(call(account_id: create_account, email: nil)).to eq(Result.failure("email is required"))
    end

    it "appends nothing when validation fails" do
      call(account_id: create_account, email: "")
      expect(invitation_events).to be_empty
    end
  end

  describe "membership invariant", :event_store do
    it "rejects an invite from a non-member" do
      account_id = create_account
      result = call(account_id:, invited_by_user_id: "stranger-1")
      expect(result).to eq(Result.failure("only members can invite players"))
    end

    it "appends nothing for a non-member" do
      call(account_id: create_account, invited_by_user_id: "stranger-1")
      expect(invitation_events).to be_empty
    end

    it "lets a member who joined by invitation invite" do
      account_id = create_account
      invitation_id = call(account_id:, email: "bob@example.com").value
      Accounts::AcceptInvitation.call(invitation_id:, user_id: "user-2", user_email: "bob@example.com")

      result = call(account_id:, email: "carol@example.com", invited_by_user_id: "user-2")
      expect(result).to be_success
    end
  end

  describe "successful invitation", :event_store do
    it "returns success with the new invitation id" do
      result = call(account_id: create_account)
      expect(result).to be_success
      expect(result.value).to be_a(String)
    end

    it "appends with the decision model's append condition (concurrency guard)" do
      account_id = create_account
      condition = nil
      allow(EventStore).to receive(:append) { |_event, append_condition| condition = append_condition }
      call(account_id:)
      expect(condition).to be_a(DcbEventStore::AppendCondition)
    end

    it "appends a PlayerInvited event with the normalised email" do
      account_id = create_account
      result = call(account_id:, email: " BOB@Example.com ")
      event = invitation_events.sole
      expect(event.data).to eq(
        invitation_id: result.value, account_id:, email: "bob@example.com", invited_by_user_id: "owner-1"
      )
      expect(event.tags).to contain_exactly(
        "invitation:#{result.value}", "account:#{account_id}", "invitee_email:bob@example.com"
      )
    end
  end

  describe "concurrency conflict", :event_store do
    it "maps ConditionNotMet to a retry failure" do
      account_id = create_account
      allow(EventStore).to receive(:append).and_raise(DcbEventStore::ConditionNotMet)
      result = call(account_id:)
      expect(result).to eq(Result.failure("the account changed while you were working — please retry"))
    end
  end
end
