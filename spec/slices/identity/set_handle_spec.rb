require "rails_helper"

RSpec.describe Identity::SetHandle do
  def handle_events
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[UserHandleSet]) ])
    )
  end

  describe "validation", :event_store do
    it "rejects a blank handle" do
      expect(described_class.call(user_id: "user-1", handle: "   ")).to eq(Result.failure("handle is required"))
    end

    it "rejects a missing handle instead of raising" do
      expect(described_class.call(user_id: "user-1", handle: nil)).to eq(Result.failure("handle is required"))
    end

    it "appends nothing when the handle is blank" do
      described_class.call(user_id: "user-1", handle: " ")
      expect(handle_events).to be_empty
    end
  end

  describe "setting a handle", :event_store do
    it "returns success with the user id" do
      expect(described_class.call(user_id: "user-1", handle: "Ace")).to eq(Result.success("user-1"))
    end

    it "appends a UserHandleSet event tagged with the user" do
      described_class.call(user_id: "user-1", handle: "Ace")
      event = handle_events.sole
      expect(event.data).to eq(user_id: "user-1", handle: "Ace")
      expect(event.tags).to eq([ "user:user-1" ])
    end

    it "strips surrounding whitespace" do
      described_class.call(user_id: "user-1", handle: "  Ace  ")
      expect(handle_events.sole.data[:handle]).to eq("Ace")
    end

    it "appends every handle change so the latest wins on fold" do
      described_class.call(user_id: "user-1", handle: "Ace")
      described_class.call(user_id: "user-1", handle: "Maverick")
      expect(handle_events.map { |event| event.data[:handle] }).to eq(%w[Ace Maverick])
    end
  end
end
