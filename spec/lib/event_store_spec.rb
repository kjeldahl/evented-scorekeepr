require "rails_helper"

RSpec.describe EventStore, :event_store do
  def event(type: "SomethingHappened", tags: [ "league:l-1" ])
    DcbEventStore::Event.new(type:, data: {}, tags:)
  end

  describe ".on_append" do
    # Hooks are deliberately global (they survive reset!), so restore the
    # registry around each example to keep examples isolated.
    around do |example|
      registered = described_class.send(:append_hooks).dup
      example.run
      described_class.send(:append_hooks).replace(registered)
    end

    it "calls the hook with a single appended event normalised to an array" do
      seen = []
      described_class.on_append { |events| seen << events }
      single = event
      described_class.append(single)
      expect(seen).to eq([ [ single ] ])
    end

    it "calls the hook with the appended events array as-is" do
      seen = []
      described_class.on_append { |events| seen << events }
      pair = [ event, event ]
      described_class.append(pair)
      expect(seen).to eq([ pair ])
    end

    it "calls the hook only after the events are readable in the store" do
      read_during_hook = nil
      query = DcbEventStore::Query.new(
        DcbEventStore::QueryItem.new(event_types: %w[SomethingHappened], tags: [ "league:l-1" ])
      )
      described_class.on_append { |_events| read_during_hook = described_class.read(query).size }
      described_class.append(event)
      expect(read_during_hook).to eq(1)
    end

    it "notifies every registered hook in registration order" do
      calls = []
      described_class.on_append { calls << :first }
      described_class.on_append { calls << :second }
      described_class.append(event)
      expect(calls).to eq(%i[first second])
    end

    it "does not notify hooks when the append condition fails" do
      projection = DcbEventStore::Projection.new(
        initial_state: 0,
        handlers: { "SomethingHappened" => ->(state, _event) { state + 1 } },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(event_types: %w[SomethingHappened], tags: [ "league:l-1" ])
        )
      )
      decision = described_class.decide(count: projection)
      described_class.append(event) # concurrent conflicting append
      seen = []
      described_class.on_append { |events| seen << events }
      expect { described_class.append(event, decision.append_condition) }
        .to raise_error(DcbEventStore::ConditionNotMet)
      expect(seen).to be_empty
    end

    it "keeps hooks registered across reset!" do
      seen = []
      described_class.on_append { |events| seen << events }
      described_class.reset!
      described_class.append(event)
      expect(seen.size).to eq(1)
    end
  end
end
