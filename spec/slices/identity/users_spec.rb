require "rails_helper"

RSpec.describe Identity::Users do
  describe ".find", :event_store do
    it "returns a user value object with id, name and email" do
      user_id = Identity::RegisterUser.call(name: "Alice", email: "alice@example.com", password: "secret123").value

      user = described_class.find(user_id)

      expect(user.id).to eq(user_id)
      expect(user.name).to eq("Alice")
      expect(user.email).to eq("alice@example.com")
    end

    it "returns nil for an unknown user id" do
      expect(described_class.find("missing-id")).to be_nil
    end

    it "returns only the requested user when several are registered" do
      Identity::RegisterUser.call(name: "Alice", email: "alice@example.com", password: "secret123")
      bob_id = Identity::RegisterUser.call(name: "Bob", email: "bob@example.com", password: "secret123").value

      expect(described_class.find(bob_id).name).to eq("Bob")
    end
  end
end
