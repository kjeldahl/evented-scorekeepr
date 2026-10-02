require "rails_helper"

RSpec.describe Identity::RegisteredEmails, :event_store do
  def register(user_id, email)
    EventStore.append(Identity::Events.user_registered(user_id:, name: user_id, email:, password_digest: "d"))
  end

  it "is empty without users" do
    expect(described_class.except("u1")).to eq([])
  end

  it "lists every other user's email in registration order" do
    register("u1", "a@example.com")
    register("u2", "b@example.com")
    register("u3", "c@example.com")
    expect(described_class.except("u2")).to eq(%w[a@example.com c@example.com])
  end

  it "queries UserRegistered events of every user" do
    item = described_class.projection.query.items.sole
    expect(item.event_types).to eq(%w[UserRegistered])
    expect(item.tags).to be_empty
  end
end
