require "rails_helper"

RSpec.describe Accounts::AllAccounts do
  def account_created(account_id:, name:)
    Accounts::Events.account_created(account_id:, name:, owner_user_id: "owner-1")
  end

  describe ".projection" do
    subject(:projection) { described_class.projection }

    it "starts with no accounts" do
      expect(projection.initial_state).to eq([])
    end

    it "collects every created account as an id/name summary" do
      events = [
        account_created(account_id: "acc-1", name: "Office"),
        account_created(account_id: "acc-2", name: "Family")
      ]
      expect(projection.fold(events)).to eq([
        described_class::Summary.new(id: "acc-1", name: "Office"),
        described_class::Summary.new(id: "acc-2", name: "Family")
      ])
    end

    it "queries all AccountCreated events without tags" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[AccountCreated])
      expect(item.tags).to eq([])
    end
  end

  describe ".all", :event_store do
    it "is empty when no account exists" do
      expect(described_class.all).to eq([])
    end

    it "lists every account in the system sorted alphabetically by name" do
      office_id = Accounts::CreateAccount.call(name: "Office", owner_user_id: "user-1").value
      family_id = Accounts::CreateAccount.call(name: "Family", owner_user_id: "user-2").value
      bowling_id = Accounts::CreateAccount.call(name: "Bowling Buddies", owner_user_id: "user-3").value

      expect(described_class.all.map { |account| [ account.id, account.name ] }).to eq([
        [ bowling_id, "Bowling Buddies" ],
        [ family_id, "Family" ],
        [ office_id, "Office" ]
      ])
    end
  end
end
