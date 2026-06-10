require "rails_helper"

RSpec.describe Identity::EmailRegistration do
  describe ".projection" do
    subject(:projection) { described_class.projection("alice@example.com") }

    it "starts unregistered" do
      expect(projection.initial_state).to be(false)
    end

    it "is registered once a UserRegistered event is folded" do
      event = Identity::Events.user_registered(
        user_id: "user-1", name: "Alice", email: "alice@example.com", password_digest: "digest"
      )
      expect(projection.fold([ event ])).to be(true)
    end

    it "queries UserRegistered events tagged with the email" do
      item = projection.query.items.sole
      expect(item.event_types).to eq([ "UserRegistered" ])
      expect(item.tags).to eq([ "user_email:alice@example.com" ])
    end
  end
end
