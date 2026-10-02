require "rails_helper"

RSpec.describe Identity::CurrentSuperAdmin do
  def super_admin_granted(user_id)
    DcbEventStore::Event.new(
      type: "SuperAdminGranted",
      data: { user_id: },
      tags: [ "user:#{user_id}" ]
    )
  end

  def handed_off(from, to)
    Identity::Events.super_admin_handed_off(from_user_id: from, to_user_id: to)
  end

  describe ".projection" do
    subject(:projection) { described_class.projection }

    it "starts with no super admin" do
      expect(projection.initial_state).to be_nil
    end

    it "is the granted user once a SuperAdminGranted event is folded" do
      expect(projection.fold([ super_admin_granted("user-1") ])).to eq("user-1")
    end

    it "is the recipient of a handoff" do
      events = [ super_admin_granted("user-1"), handed_off("user-1", "user-2") ]
      expect(projection.fold(events)).to eq("user-2")
    end

    it "follows a chain of handoffs, latest winning" do
      events = [ super_admin_granted("user-1"), handed_off("user-1", "user-2"), handed_off("user-2", "user-3") ]
      expect(projection.fold(events)).to eq("user-3")
    end

    it "queries every grant and handoff event regardless of user" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[SuperAdminGranted SuperAdminHandedOff])
      expect(item.tags).to be_empty
    end
  end
end
