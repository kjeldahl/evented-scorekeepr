# Declines an invitation as the invited user. Only the signed-in user whose
# email matches the invitation may decline, and only while it is pending —
# the decision model's append condition makes declining race-free against a
# concurrent accept or revoke.
module Accounts
  class DeclineInvitation
    def self.call(invitation_id:, user_id:, user_email:)
      decision = EventStore.decide(invitation: InvitationState.projection(invitation_id))
      invitation = decision.states.fetch(:invitation)
      failure = rejection(invitation, user_email)
      return failure if failure

      event = Events.invitation_declined(invitation_id:, account_id: invitation.account_id, user_id:)
      EventStore.append(event, decision.append_condition)
      Result.success(invitation.account_id)
    rescue DcbEventStore::ConditionNotMet
      Result.failure("the invitation is no longer pending")
    end

    def self.rejection(invitation, user_email)
      return Result.failure("the invitation was not found") unless invitation
      return Result.failure("the invitation was not sent to this user's email") unless sent_to?(invitation, user_email)

      Result.failure("the invitation is no longer pending") unless invitation.pending?
    end
    private_class_method :rejection

    def self.sent_to?(invitation, user_email)
      invitation.email == user_email.to_s.strip.downcase
    end
    private_class_method :sent_to?
  end
end
