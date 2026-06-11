# Decision-model projection over one invitation: who it was sent to, which
# account it opens, and whether it is still pending or already settled
# (accepted, revoked or declined). The append condition built from its
# narrow invitation:{id} query makes settling race-free.
module Accounts
  module InvitationState
    State = Data.define(:account_id, :email, :status) do
      def pending? = status == :pending
    end

    extend self

    def projection(invitation_id)
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: {
          "PlayerInvited" => ->(_state, event) {
            State.new(account_id: event.data.fetch(:account_id), email: event.data.fetch(:email), status: :pending)
          },
          "InvitationAccepted" => ->(state, _event) { state&.with(status: :accepted) },
          "InvitationRevoked" => ->(state, _event) { state&.with(status: :revoked) },
          "InvitationDeclined" => ->(state, _event) { state&.with(status: :declined) }
        },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(
            event_types: %w[PlayerInvited InvitationAccepted InvitationRevoked InvitationDeclined],
            tags: "invitation:#{invitation_id}"
          )
        )
      )
    end
  end
end
