require "rails_helper"

RSpec.describe Identity::UserExistence do
  def user_registered(user_id: "user-1")
    DcbEventStore::Event.new(
      type: "UserRegistered",
      data: { user_id:, name: "Root", email: "root@example.com", password_digest: "digest-1" },
      tags: [ "user:#{user_id}", "user_email:root@example.com" ]
    )
  end

  describe ".projection" do
    subject(:projection) { described_class.projection(user_id: "user-1") }

    it "starts as not existing" do
      expect(projection.initial_state).to be(false)
    end

    it "exists once a UserRegistered event is folded" do
      expect(projection.fold([ user_registered ])).to be(true)
    end

    it "queries UserRegistered tagged with the user id" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[UserRegistered])
      expect(item.tags).to eq([ "user:user-1" ])
    end
  end
end
