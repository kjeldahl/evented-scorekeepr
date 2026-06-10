require "rails_helper"

RSpec.describe Accounts::Account do
  describe ".projection" do
    subject(:projection) { described_class.projection("acc-1") }

    it "starts with no account" do
      expect(projection.initial_state).to be_nil
    end

    it "builds a summary from AccountCreated" do
      event = Accounts::Events.account_created(account_id: "acc-1", name: "Office", owner_user_id: "user-1")
      summary = projection.fold([ event ])
      expect(summary.id).to eq("acc-1")
      expect(summary.name).to eq("Office")
      expect(summary.owner_user_id).to eq("user-1")
    end

    it "queries AccountCreated events tagged with the account" do
      item = projection.query.items.sole
      expect(item.event_types).to eq([ "AccountCreated" ])
      expect(item.tags).to eq([ "account:acc-1" ])
    end
  end

  describe ".find", :event_store do
    it "returns nil for an unknown account" do
      expect(described_class.find("missing")).to be_nil
    end

    it "returns the summary of a created account" do
      account_id = Accounts::CreateAccount.call(name: "Office", owner_user_id: "user-1").value
      summary = described_class.find(account_id)
      expect(summary).to eq(described_class::Summary.new(id: account_id, name: "Office", owner_user_id: "user-1"))
    end
  end
end
