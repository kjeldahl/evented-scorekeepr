require "rails_helper"

RSpec.describe Accounts::InvitationState do
  subject(:projection) { described_class.projection("inv-1") }

  let(:invited) do
    Accounts::Events.player_invited(
      invitation_id: "inv-1", account_id: "acc-1", email: "bob@example.com", invited_by_user_id: "user-1"
    )
  end
  let(:accepted) do
    Accounts::Events.invitation_accepted(invitation_id: "inv-1", account_id: "acc-1", user_id: "user-2")
  end

  it "starts with no invitation" do
    expect(projection.initial_state).to be_nil
  end

  it "captures account and email from PlayerInvited, not yet accepted" do
    state = projection.fold([ invited ])
    expect(state.account_id).to eq("acc-1")
    expect(state.email).to eq("bob@example.com")
    expect(state.accepted).to be(false)
  end

  it "marks the invitation accepted once InvitationAccepted is folded" do
    state = projection.fold([ invited, accepted ])
    expect(state.accepted).to be(true)
  end

  it "stays empty when an acceptance arrives without the invitation" do
    expect(projection.fold([ accepted ])).to be_nil
  end

  it "queries both invitation event types with the invitation tag" do
    item = projection.query.items.sole
    expect(item.event_types).to eq(%w[PlayerInvited InvitationAccepted])
    expect(item.tags).to eq([ "invitation:inv-1" ])
  end
end
