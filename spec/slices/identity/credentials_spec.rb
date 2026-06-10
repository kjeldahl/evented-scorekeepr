require "rails_helper"

RSpec.describe Identity::Credentials do
  describe ".projection" do
    subject(:projection) { described_class.projection("alice@example.com") }

    let(:event) do
      Identity::Events.user_registered(
        user_id: "user-1", name: "Alice", email: "alice@example.com", password_digest: "digest-1"
      )
    end

    it "starts with no credentials" do
      expect(projection.initial_state).to be_nil
    end

    it "folds UserRegistered into user_id + password_digest" do
      expect(projection.fold([ event ])).to eq(user_id: "user-1", password_digest: "digest-1")
    end

    it "queries UserRegistered events tagged with the email" do
      item = projection.query.items.sole
      expect(item.event_types).to eq([ "UserRegistered" ])
      expect(item.tags).to eq([ "user_email:alice@example.com" ])
    end
  end

  describe ".find_by_email", :event_store do
    it "returns the stored credentials for a registered email" do
      user_id = Identity::RegisterUser.call(name: "Alice", email: "alice@example.com", password: "secret123").value
      credentials = described_class.find_by_email("alice@example.com")
      expect(credentials[:user_id]).to eq(user_id)
    end

    it "returns nil for an unknown email" do
      expect(described_class.find_by_email("nobody@example.com")).to be_nil
    end
  end
end
