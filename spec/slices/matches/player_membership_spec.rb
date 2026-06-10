require "rails_helper"

RSpec.describe Matches::PlayerMembership do
  def account_created(account_id: "acc-1", owner: "user-1")
    DcbEventStore::Event.new(
      type: "AccountCreated",
      data: { account_id:, name: "Office", owner_user_id: owner },
      tags: [ "account:#{account_id}", "user:#{owner}" ]
    )
  end

  def invitation_accepted(account_id: "acc-1", user_id: "user-2")
    DcbEventStore::Event.new(
      type: "InvitationAccepted",
      data: { invitation_id: "inv-#{user_id}", account_id:, user_id: },
      tags: [ "invitation:inv-#{user_id}", "account:#{account_id}", "user:#{user_id}" ]
    )
  end

  describe ".projection" do
    subject(:projection) { described_class.projection(account_id: "acc-1", player_ids: %w[user-1 user-2]) }

    it "starts with no members" do
      expect(projection.initial_state).to eq([])
    end

    it "collects the owner and accepted invitees, without duplicates" do
      events = [ account_created, invitation_accepted, invitation_accepted ]
      expect(projection.fold(events)).to eq(%w[user-1 user-2])
    end

    it "builds one narrow query item per player" do
      expect(projection.query.items.map(&:tags)).to eq([
        [ "account:acc-1", "user:user-1" ],
        [ "account:acc-1", "user:user-2" ]
      ])
      expect(projection.query.items.map(&:event_types).uniq.sole).to eq(%w[AccountCreated InvitationAccepted])
    end
  end
end
