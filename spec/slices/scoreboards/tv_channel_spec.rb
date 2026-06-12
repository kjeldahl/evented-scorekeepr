require "rails_helper"

RSpec.describe Scoreboards::TvChannel, type: :channel do
  def account_created(account_id: "acc-1", owner: "user-1")
    DcbEventStore::Event.new(
      type: "AccountCreated",
      data: { account_id:, name: "Office", owner_user_id: owner },
      tags: [ "account:#{account_id}", "user:#{owner}" ]
    )
  end

  def super_admin_granted(user_id:)
    DcbEventStore::Event.new(
      type: "SuperAdminGranted",
      data: { user_id: },
      tags: [ "user:#{user_id}" ]
    )
  end

  describe "#subscribed", :event_store do
    it "confirms a member and streams the league's event-tag stream" do
      EventStore.append(account_created(owner: "user-1"))
      stub_connection current_user_id: "user-1"
      subscribe account_id: "acc-1", league_id: "league-1"
      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("events:league:league-1")
    end

    it "rejects a signed-in non-member" do
      EventStore.append(account_created(owner: "user-1"))
      stub_connection current_user_id: "stranger"
      subscribe account_id: "acc-1", league_id: "league-1"
      expect(subscription).to be_rejected
    end

    it "rejects a member of a different account (tenancy)" do
      EventStore.append(account_created(account_id: "acc-2", owner: "user-1"))
      stub_connection current_user_id: "user-1"
      subscribe account_id: "acc-1", league_id: "league-1"
      expect(subscription).to be_rejected
    end

    it "confirms a super admin who is not a member (view-only gate)" do
      EventStore.append([ account_created(owner: "user-1"), super_admin_granted(user_id: "root") ])
      stub_connection current_user_id: "root"
      subscribe account_id: "acc-1", league_id: "league-1"
      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("events:league:league-1")
    end
  end
end
