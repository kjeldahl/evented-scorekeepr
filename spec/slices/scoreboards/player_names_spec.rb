require "rails_helper"

RSpec.describe Scoreboards::PlayerNames do
  def user_registered(user_id:, name:, email: "#{name.downcase}@example.com")
    DcbEventStore::Event.new(
      type: "UserRegistered",
      data: { user_id:, name:, email:, password_digest: "x" },
      tags: [ "user:#{user_id}", "user_email:#{email}" ]
    )
  end

  describe ".projection" do
    subject(:projection) { described_class.projection(%w[u-1 u-2]) }

    it "starts with no names" do
      expect(projection.initial_state).to eq({})
    end

    it "folds UserRegistered into an id => name map" do
      names = projection.fold([ user_registered(user_id: "u-1", name: "Alice"),
                                user_registered(user_id: "u-2", name: "Bob") ])
      expect(names).to eq({ "u-1" => "Alice", "u-2" => "Bob" })
    end

    it "queries one narrow item per user" do
      expect(projection.query.items.map(&:tags)).to eq([ [ "user:u-1" ], [ "user:u-2" ] ])
      expect(projection.query.items.map(&:event_types).uniq).to eq([ %w[UserRegistered] ])
    end
  end

  describe ".for", :event_store do
    it "returns an empty map for no ids without touching the store" do
      EventStore.append([ user_registered(user_id: "u-1", name: "Alice") ])
      expect(EventStore).not_to receive(:project)
      expect(described_class.for([])).to eq({})
    end

    it "resolves the names of the given users only" do
      EventStore.append([ user_registered(user_id: "u-1", name: "Alice"),
                          user_registered(user_id: "u-2", name: "Bob") ])
      expect(described_class.for([ "u-1" ])).to eq({ "u-1" => "Alice" })
    end

    it "deduplicates the requested ids" do
      EventStore.append([ user_registered(user_id: "u-1", name: "Alice") ])
      expect(described_class.for(%w[u-1 u-1])).to eq({ "u-1" => "Alice" })
    end

    it "queries each requested id once, even when repeated" do
      items = nil
      allow(EventStore).to receive(:project) { |projection| items = projection.query.items and {} }
      described_class.for(%w[u-1 u-1])
      expect(items).to eq(described_class.projection(%w[u-1]).query.items)
    end
  end
end
