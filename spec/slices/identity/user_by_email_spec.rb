require "rails_helper"

RSpec.describe Identity::UserByEmail do
  subject(:projection) { described_class.projection("a@example.com") }

  it "starts with no user" do
    expect(projection.initial_state).to be_nil
  end

  it "folds to the registered user's id" do
    event = Identity::Events.user_registered(user_id: "u1", name: "A", email: "a@example.com", password_digest: "d")
    expect(projection.fold([ event ])).to eq("u1")
  end

  it "queries UserRegistered by the email tag" do
    item = projection.query.items.sole
    expect(item.event_types).to eq(%w[UserRegistered])
    expect(item.tags).to eq([ "user_email:a@example.com" ])
  end
end
