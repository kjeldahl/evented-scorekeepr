# Revokes a pending outgoing invitation. Only members of the account can
# revoke, the invitation must belong to that account and must still be
# pending; the decision model's append condition makes revocation race-free
# against a concurrent accept or decline.
module Accounts
  class RevokeInvitation
    def self.call(invitation_id:, account_id:, user_id:)
      decision = EventStore.decide(
        invitation: InvitationState.projection(invitation_id),
        member: Membership.projection(account_id:, user_id:)
      )
      failure = rejection(decision.states, account_id)
      return failure if failure

      event = Events.invitation_revoked(invitation_id:, account_id:, revoked_by_user_id: user_id)
      EventStore.append(event, decision.append_condition)
      Result.success(invitation_id)
    rescue DcbEventStore::ConditionNotMet
      Result.failure("the invitation is no longer pending")
    end

    def self.rejection(states, account_id)
      return Result.failure("only members can revoke invitations") unless states.fetch(:member)

      invitation = states.fetch(:invitation)
      return Result.failure("the invitation was not found") unless invitation&.account_id == account_id

      Result.failure("the invitation is no longer pending") unless invitation.pending?
    end
    private_class_method :rejection
  end
end
