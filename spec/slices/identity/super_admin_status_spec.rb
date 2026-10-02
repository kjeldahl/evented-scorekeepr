require "rails_helper"

RSpec.describe Identity::SuperAdminStatus do
  def super_admin_granted(user_id: "user-1")
    Identity::Events.super_admin_granted(user_id:)
  end

  describe ".projection" do
    subject(:projection) { described_class.projection }

    it "starts with nobody as super admin" do
      expect(projection.initial_state).to be_nil
    end

    it "folds to the id of the granted user" do
      expect(projection.fold([ super_admin_granted(user_id: "user-7") ])).to eq("user-7")
    end

    it "queries SuperAdminGranted by the global super_admin tag" do
      item = projection.query.items.sole
      expect(item.event_types).to eq(%w[SuperAdminGranted])
      expect(item.tags).to eq(%w[super_admin])
    end
  end
end
