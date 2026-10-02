require "rails_helper"

RSpec.describe ImpersonationAudit do
  let(:context) do
    { impersonation_id: "imp-1", super_admin_user_id: "root-1", impersonated_user_id: "bob-1" }
  end

  def match_event
    DcbEventStore::Event.new(
      type: "MatchRegistered",
      data: { match_id: "m-1" },
      tags: [ "match:m-1", "league:lg-1", "account:acc-1" ]
    )
  end

  def recorded_events
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[ImpersonatedActionRecorded]) ])
    )
  end

  # CurrentAttributes persist within a thread; reset so a test never leaks its
  # impersonation context into another example's append hook.
  after { Current.reset }

  describe ".record", :event_store do
    it "does not audit a super admin handoff made during impersonation" do
      Current.impersonation = context
      described_class.record([ DcbEventStore::Event.new(type: "SuperAdminHandedOff", data: {}, tags: [ "user:a" ]) ])
      expect(recorded_events).to be_empty
    end

    it "records nothing when no impersonation is in effect" do
      Current.impersonation = nil
      described_class.record([ match_event ])
      expect(recorded_events).to be_empty
    end

    it "records an ImpersonatedActionRecorded tying the action to the super admin" do
      Current.impersonation = context
      described_class.record([ match_event ])

      event = recorded_events.sole
      expect(event.data).to eq(
        impersonation_id: "imp-1", super_admin_user_id: "root-1", impersonated_user_id: "bob-1",
        actions: [ { type: "MatchRegistered", tags: [ "match:m-1", "league:lg-1", "account:acc-1" ] } ]
      )
      expect(event.tags).to contain_exactly("impersonation:imp-1", "user:root-1")
    end

    it "does not audit impersonation lifecycle events" do
      Current.impersonation = context
      lifecycle = DcbEventStore::Event.new(type: "ImpersonationEnded", data: {}, tags: [])
      described_class.record([ lifecycle ])
      expect(recorded_events).to be_empty
    end

    it "does not audit its own audit events (no recursion)" do
      Current.impersonation = context
      own = DcbEventStore::Event.new(type: "ImpersonatedActionRecorded", data: {}, tags: [])
      described_class.record([ own ])
      expect(recorded_events).to be_empty
    end

    it "records only the auditable actions from a mixed batch" do
      Current.impersonation = context
      lifecycle = DcbEventStore::Event.new(type: "ImpersonationStarted", data: {}, tags: [])
      described_class.record([ lifecycle, match_event ])

      event = recorded_events.sole
      expect(event.data.fetch(:actions)).to eq(
        [ { type: "MatchRegistered", tags: [ "match:m-1", "league:lg-1", "account:acc-1" ] } ]
      )
    end
  end
end
