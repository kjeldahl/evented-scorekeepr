require "rails_helper"

RSpec.describe Identity::Events do
  describe ".user_registered" do
    subject(:event) do
      described_class.user_registered(
        user_id: "user-1", name: "Alice", email: " Alice@Example.COM ", password_digest: "digest-1"
      )
    end

    it "has the UserRegistered type" do
      expect(event.type).to eq("UserRegistered")
    end

    it "carries user_id, name, normalised email and password_digest as data" do
      expect(event.data).to eq(
        user_id: "user-1", name: "Alice", email: "alice@example.com", password_digest: "digest-1"
      )
    end

    it "is tagged with the user id and the normalised email" do
      expect(event.tags).to contain_exactly("user:user-1", "user_email:alice@example.com")
    end
  end

  describe ".user_handle_set" do
    subject(:event) { described_class.user_handle_set(user_id: "user-1", handle: "Ace") }

    it "has the UserHandleSet type" do
      expect(event.type).to eq("UserHandleSet")
    end

    it "carries user_id and handle as data" do
      expect(event.data).to eq(user_id: "user-1", handle: "Ace")
    end

    it "is tagged with the user id" do
      expect(event.tags).to eq([ "user:user-1" ])
    end
  end

  describe ".super_admin_granted" do
    subject(:event) { described_class.super_admin_granted(user_id: "user-1") }

    it "has the SuperAdminGranted type" do
      expect(event.type).to eq("SuperAdminGranted")
    end

    it "carries the user_id as data" do
      expect(event.data).to eq(user_id: "user-1")
    end

    it "is tagged with the user id" do
      expect(event.tags).to eq([ "user:user-1" ])
    end
  end

  describe ".super_admin_handed_off" do
    subject(:event) { described_class.super_admin_handed_off(from_user_id: "user-1", to_user_id: "user-2") }

    it "has the SuperAdminHandedOff type" do
      expect(event.type).to eq("SuperAdminHandedOff")
    end

    it "carries both user ids as data" do
      expect(event.data).to eq(from_user_id: "user-1", to_user_id: "user-2")
    end

    it "is tagged with both users" do
      expect(event.tags).to eq([ "user:user-1", "user:user-2" ])
    end
  end
end
