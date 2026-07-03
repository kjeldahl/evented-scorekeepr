require "rails_helper"

RSpec.describe ImpersonationSession do
  def call(super_admin_user_id: "root-1", impersonation_id: "imp-1")
    described_class.stop(super_admin_user_id:, impersonation_id:)
  end

  def ended_events
    EventStore.read(
      DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[ImpersonationEnded]) ])
    )
  end

  describe ".stop", :event_store do
    it "returns success with the impersonation id" do
      expect(call).to eq(Result.success("imp-1"))
    end

    it "appends an ImpersonationEnded event tied to the super admin" do
      call
      event = ended_events.sole
      expect(event.type).to eq("ImpersonationEnded")
      expect(event.data).to eq(impersonation_id: "imp-1", super_admin_user_id: "root-1")
      expect(event.tags).to contain_exactly("impersonation:imp-1", "user:root-1")
    end
  end
end
