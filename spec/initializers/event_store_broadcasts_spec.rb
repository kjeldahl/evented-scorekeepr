require "rails_helper"

# The broadcast bridge (config/initializers/event_store_broadcasts.rb) is
# registered once at boot: every successful append broadcasts the event type
# on "events:{tag}" for every tag of every appended event. The test cable
# adapter records broadcasts for inspection.
RSpec.describe "event store ActionCable broadcasts", :event_store do
  before { ActionCable.server.pubsub.clear }

  def broadcasts(stream)
    ActionCable.server.pubsub.broadcasts(stream).map { |payload| JSON.parse(payload) }
  end

  it "broadcasts the event type on each tag's stream" do
    EventStore.append(
      DcbEventStore::Event.new(
        type: "MatchRegistered",
        data: { league_id: "l-1" },
        tags: [ "league:l-1", "account:a-1" ]
      )
    )
    expect(broadcasts("events:league:l-1")).to eq([ { "type" => "MatchRegistered" } ])
    expect(broadcasts("events:account:a-1")).to eq([ { "type" => "MatchRegistered" } ])
  end

  it "broadcasts once per event for every appended event" do
    EventStore.append([
      DcbEventStore::Event.new(type: "LeagueRenamed", data: {}, tags: [ "league:l-1" ]),
      DcbEventStore::Event.new(type: "LeagueClosed", data: {}, tags: [ "league:l-1" ])
    ])
    expect(broadcasts("events:league:l-1"))
      .to eq([ { "type" => "LeagueRenamed" }, { "type" => "LeagueClosed" } ])
  end

  it "does not broadcast on streams for tags the event does not carry" do
    EventStore.append(DcbEventStore::Event.new(type: "MatchRegistered", data: {}, tags: [ "league:l-1" ]))
    expect(broadcasts("events:league:other")).to be_empty
  end
end
