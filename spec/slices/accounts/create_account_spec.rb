require "rails_helper"

RSpec.describe Accounts::CreateAccount do
  def call(name: "Office", owner_user_id: "user-1")
    described_class.call(name:, owner_user_id:)
  end

  def stored_events
    EventStore.read(DcbEventStore::Query.all)
  end

  describe "validation" do
    it "rejects a blank name" do
      expect(call(name: "  ")).to eq(Result.failure("name is required"))
    end

    it "rejects a nil name" do
      expect(call(name: nil)).to eq(Result.failure("name is required"))
    end

    it "appends nothing when validation fails", :event_store do
      call(name: "")
      expect(stored_events).to be_empty
    end
  end

  describe "successful creation", :event_store do
    it "returns success with the new account id" do
      result = call
      expect(result).to be_success
      expect(result.value).to be_a(String)
    end

    it "appends an AccountCreated event with the stripped name" do
      result = call(name: " Office ")
      event = stored_events.sole
      expect(event.type).to eq("AccountCreated")
      expect(event.data).to eq(account_id: result.value, name: "Office", owner_user_id: "user-1")
      expect(event.tags).to contain_exactly("account:#{result.value}", "user:user-1")
    end

    it "makes the owner a member from creation" do
      result = call
      expect(Accounts::Membership.member?(account_id: result.value, user_id: "user-1")).to be(true)
    end

    it "does not make anyone else a member" do
      result = call
      expect(Accounts::Membership.member?(account_id: result.value, user_id: "user-2")).to be(false)
    end

    it "generates a distinct account id per creation" do
      expect(call.value).not_to eq(call.value)
    end
  end
end
