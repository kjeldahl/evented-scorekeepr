require "rails_helper"

RSpec.describe Identity::CurrentSuperAdmin do
  def super_admin_granted(user_id)
    DcbEventStore::Event.new(
      type: "SuperAdminGranted",
      data: { user_id: },
      tags: [ "user:#{user_id}" ]
    )
  end

  def super_admin_revoked(user_id)
    DcbEventStore::Event.new(
      type: "SuperAdminRevoked",
      data: { user_id: },
      tags: [ "user:#{user_id}" ]
    )
  end

  describe ".projection" do
    subject(:projection) { described_class.projection }

    it "starts with no super admin" do
      expect(projection.initial_state).to be_nil
    end

    it "is the granted user once a SuperAdminGranted event is folded" do
      expect(projection.fold([ super_admin_granted("user-1") ])).to eq("user-1")
    end

    it "keeps the first granted user" do
      expect(projection.fold([ super_admin_granted("user-1"), super_admin_granted("user-2") ])).to eq("user-1")
    end

    it "clears the holder when they are revoked" do
      expect(projection.fold([ super_admin_granted("user-1"), super_admin_revoked("user-1") ])).to be_nil
    end

    it "keeps the holder when somebody else is revoked" do
      expect(projection.fold([ super_admin_granted("user-1"), super_admin_revoked("user-2") ])).to eq("user-1")
    end

    it "hands over: revoke then grant makes the recipient the holder" do
      events = [ super_admin_granted("user-1"), super_admin_revoked("user-1"), super_admin_granted("user-2") ]
      expect(projection.fold(events)).to eq("user-2")
    end

    it "queries every grant and revoke event regardless of user" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[SuperAdminGranted SuperAdminRevoked])
      expect(item.tags).to be_empty
    end
  end
end

RSpec.describe Identity::CurrentSuperAdmin, ".holder", :event_store do
  it "is nil without a grant" do
    expect(described_class.holder).to be_nil
  end

  it "is the granted user" do
    EventStore.append(Identity::Events.super_admin_granted(user_id: "u1"))
    expect(described_class.holder).to eq("u1")
  end
end
