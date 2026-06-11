require "rails_helper"

RSpec.describe Identity::Users do
  describe ".find", :event_store do
    it "returns a user value object with id, name, email and no handle" do
      user_id = Identity::RegisterUser.call(name: "Alice", email: "alice@example.com", password: "secret123").value

      user = described_class.find(user_id)

      expect(user.id).to eq(user_id)
      expect(user.name).to eq("Alice")
      expect(user.email).to eq("alice@example.com")
      expect(user.handle).to be_nil
    end

    it "carries the latest handle once one is set" do
      user_id = Identity::RegisterUser.call(name: "Alice", email: "alice@example.com", password: "secret123").value
      Identity::SetHandle.call(user_id:, handle: "Ace")
      Identity::SetHandle.call(user_id:, handle: "Maverick")

      expect(described_class.find(user_id).handle).to eq("Maverick")
    end

    it "ignores a handle event without a registration" do
      Identity::SetHandle.call(user_id: "ghost", handle: "Ace")
      expect(described_class.find("ghost")).to be_nil
    end

    it "returns nil for an unknown user id" do
      expect(described_class.find("missing-id")).to be_nil
    end

    it "returns only the requested user when several are registered" do
      alice_id = Identity::RegisterUser.call(name: "Alice", email: "alice@example.com", password: "secret123").value
      Identity::RegisterUser.call(name: "Bob", email: "bob@example.com", password: "secret123")

      expect(described_class.find(alice_id).name).to eq("Alice")
    end
  end

  describe ".projection" do
    it "queries the user's identity event types tagged with the user" do
      item = described_class.projection("user-1").query.items.sole
      expect(item.event_types).to eq(%w[UserRegistered UserHandleSet])
      expect(item.tags).to eq([ "user:user-1" ])
    end
  end
end
