# Read model for the account page's outgoing invitations: the invites sent
# from an account (PlayerInvited folded by the account tag) that have not
# been settled yet — accepted, revoked or declined — in the order they were
# sent.
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
          "InvitationAccepted" => ->(state, event) { remove(state, event) },
          "InvitationRevoked" => ->(state, event) { remove(state, event) },
          "InvitationDeclined" => ->(state, event) { remove(state, event) }
        },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(
            event_types: %w[PlayerInvited InvitationAccepted InvitationRevoked InvitationDeclined],
            tags: "account:#{account_id}"
          )
        )
      )
    end

    def pending(event)
      invitation_id = event.data.fetch(:invitation_id)
      { invitation_id => OutgoingInvitation.new(invitation_id:, email: event.data.fetch(:email)) }
    end

    def remove(state, event)
      state.except(event.data.fetch(:invitation_id))
    end
  end
end
