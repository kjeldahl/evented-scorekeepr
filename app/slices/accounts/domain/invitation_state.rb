# Decision-model projection over one invitation: who it was sent to, which
# account it opens, and whether it has been accepted. The append condition
# built from its narrow invitation:{id} query makes acceptance race-free.
module Accounts
  module InvitationState
    State = Data.define(:account_id, :email, :accepted)

    module_function

    def projection(invitation_id)
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: {
          "PlayerInvited" => ->(_state, event) {
            State.new(account_id: event.data[:account_id], email: event.data[:email], accepted: false)
          },
          "InvitationAccepted" => ->(state, _event) { state&.with(accepted: true) }
        },
        query: DcbEventStore::Query.new([
          DcbEventStore::QueryItem.new(
            event_types: %w[PlayerInvited InvitationAccepted],
            tags: [ "invitation:#{invitation_id}" ]
          )
        ])
      )
    end
  end
end
