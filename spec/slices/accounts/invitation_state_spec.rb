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
  let(:revoked) do
    Accounts::Events.invitation_revoked(invitation_id: "inv-1", account_id: "acc-1", revoked_by_user_id: "user-1")
  end
  let(:declined) do
    Accounts::Events.invitation_declined(invitation_id: "inv-1", account_id: "acc-1", user_id: "user-2")
  end

  it "starts with no invitation" do
    expect(projection.initial_state).to be_nil
  end

  it "captures account and email from PlayerInvited, still pending" do
    state = projection.fold([ invited ])
    expect(state.account_id).to eq("acc-1")
    expect(state.email).to eq("bob@example.com")
    expect(state.status).to eq(:pending)
    expect(state.pending?).to be(true)
  end

  it "settles as accepted once InvitationAccepted is folded" do
    state = projection.fold([ invited, accepted ])
    expect(state.status).to eq(:accepted)
    expect(state.pending?).to be(false)
  end

  it "settles as revoked once InvitationRevoked is folded" do
    state = projection.fold([ invited, revoked ])
    expect(state.status).to eq(:revoked)
    expect(state.pending?).to be(false)
  end

  it "settles as declined once InvitationDeclined is folded" do
    state = projection.fold([ invited, declined ])
    expect(state.status).to eq(:declined)
    expect(state.pending?).to be(false)
  end

  it "stays empty when a settling event arrives without the invitation" do
    expect(projection.fold([ accepted ])).to be_nil
    expect(projection.fold([ revoked ])).to be_nil
    expect(projection.fold([ declined ])).to be_nil
  end

  it "queries all invitation event types with the invitation tag" do
    item = projection.query.items.sole
    expect(item.event_types).to eq(%w[PlayerInvited InvitationAccepted InvitationRevoked InvitationDeclined])
    expect(item.tags).to eq([ "invitation:inv-1" ])
  end
end
