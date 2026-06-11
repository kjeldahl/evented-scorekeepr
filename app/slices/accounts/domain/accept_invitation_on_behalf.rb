# Development tooling: accepts an outgoing invitation as the invited player,
# looked up by the invitation's email (folding identity's UserRegistered
# events — the cross-slice contract). Delegates to AcceptInvitation, so the
# single-acceptance and email invariants hold exactly as for a normal
# acceptance. Only routed outside production.
module Accounts
  class AcceptInvitationOnBehalf
    def self.call(invitation_id:)
      invitation = EventStore.project(InvitationState.projection(invitation_id))
      return Result.failure("the invitation was not found") unless invitation

      user_id = EventStore.project(registered_user_id_projection(invitation.email))
      return Result.failure("the invited player has not registered yet") unless user_id

      AcceptInvitation.call(invitation_id:, user_id:, user_email: invitation.email)
    end

    def self.registered_user_id_projection(email)
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: { "UserRegistered" => ->(_state, event) { event.data.fetch(:user_id) } },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(event_types: "UserRegistered", tags: "user_email:#{email}")
        )
      )
    end
  end
end
