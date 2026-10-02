require "rails_helper"

RSpec.describe Accounts::SuperAdmin do
  def super_admin_granted(user_id: "user-1")
    DcbEventStore::Event.new(
      type: "SuperAdminGranted",
      data: { user_id: },
      tags: [ "user:#{user_id}" ]
    )
  end

  def handed_off(from, to)
    DcbEventStore::Event.new(
      type: "SuperAdminHandedOff",
      data: { from_user_id: from, to_user_id: to },
      tags: [ "user:#{from}", "user:#{to}" ]
    )
  end

  describe ".projection" do
    subject(:projection) { described_class.projection(user_id: "user-1") }

    it "starts as not a super admin" do
      expect(projection.initial_state).to be(false)
    end

    it "is a super admin once a SuperAdminGranted event is folded" do
      expect(projection.fold([ super_admin_granted ])).to be(true)
    end

    it "is a super admin as the recipient of a handoff" do
      expect(projection.fold([ handed_off("user-0", "user-1") ])).to be(true)
    end

    it "stops being a super admin once they hand off" do
      expect(projection.fold([ super_admin_granted, handed_off("user-1", "user-2") ])).to be(false)
    end

    it "is a super admin again when handed back" do
      events = [ super_admin_granted, handed_off("user-1", "user-2"), handed_off("user-2", "user-1") ]
      expect(projection.fold(events)).to be(true)
    end

    it "queries grants and handoffs tagged with the user id" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[SuperAdminGranted SuperAdminHandedOff])
      expect(item.tags).to eq([ "user:user-1" ])
    end
  end

  describe ".super_admin?", :event_store do
    it "is false for a user who was never granted" do
      expect(described_class.super_admin?(user_id: "user-1")).to be(false)
    end

    it "is true once a grant is stored" do
      EventStore.append([ super_admin_granted ])
      expect(described_class.super_admin?(user_id: "user-1")).to be(true)
    end

    it "grants nothing to another user (scoping)" do
      EventStore.append([ super_admin_granted ])
      expect(described_class.super_admin?(user_id: "user-2")).to be(false)
    end
  end
end
