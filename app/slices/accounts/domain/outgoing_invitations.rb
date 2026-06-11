# Read model for the account page's outgoing invitations: the invites sent
# from an account (PlayerInvited folded by the account tag) that have not
# been accepted yet, in the order they were sent.
module Accounts
  module OutgoingInvitations
    OutgoingInvitation = Data.define(:invitation_id, :email)

    extend self

    def for_account(account_id)
      EventStore.project(projection(account_id)).values
    end

    def projection(account_id)
      DcbEventStore::Projection.new(
        initial_state: {},
        handlers: {
          "PlayerInvited" => ->(state, event) { state.merge(pending(event)) },
          "InvitationAccepted" => ->(state, event) { state.except(event.data.fetch(:invitation_id)) }
        },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(
            event_types: %w[PlayerInvited InvitationAccepted],
            tags: "account:#{account_id}"
          )
        )
      )
    end

    def pending(event)
      invitation_id = event.data.fetch(:invitation_id)
      { invitation_id => OutgoingInvitation.new(invitation_id:, email: event.data.fetch(:email)) }
    end
  end
end
