# Read model for "my pending invitations": the invitations sent to an email
# (PlayerInvited folded by the invitee_email tag) that have not been
# accepted yet, decorated with the account name for display.
module Accounts
  module PendingInvitations
    PendingInvitation = Data.define(:invitation_id, :account_id, :account_name, :email)

    extend self

    def for_email(email)
      email = email.to_s.strip.downcase
      EventStore.project(invitations_projection(email))
                .reject { |invitation| accepted?(invitation.fetch(:invitation_id)) }
                .map { |invitation| decorate(invitation) }
    end

    def invitations_projection(email)
      DcbEventStore::Projection.new(
        initial_state: [],
        handlers: { "PlayerInvited" => ->(state, event) { state + [ event.data ] } },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(event_types: "PlayerInvited", tags: "invitee_email:#{email}")
        )
      )
    end

    def accepted?(invitation_id)
      EventStore.project(accepted_projection(invitation_id))
    end

    def accepted_projection(invitation_id)
      DcbEventStore::Projection.new(
        initial_state: false,
        handlers: { "InvitationAccepted" => ->(_state, _event) { true } },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(event_types: "InvitationAccepted", tags: "invitation:#{invitation_id}")
        )
      )
    end

    def decorate(invitation)
      PendingInvitation.new(
        invitation_id: invitation.fetch(:invitation_id),
        account_id: invitation.fetch(:account_id),
        account_name: Account.find(invitation.fetch(:account_id))&.name,
        email: invitation.fetch(:email)
      )
    end
  end
end
