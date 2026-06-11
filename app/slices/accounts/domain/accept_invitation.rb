# Accepts an invitation, making the accepting user a member of the account.
# Only the signed-in user whose email matches the invitation may accept, and
# only while the invitation is pending: an invitation settles exactly once —
# by acceptance, revocation or decline — which the invitation decision
# model's append condition enforces, so two concurrent settlements cannot
# both succeed.
module Accounts
  class AcceptInvitation
    SETTLED_REJECTIONS = {
      accepted: "the invitation has already been accepted",
      revoked: "the invitation has been revoked",
      declined: "the invitation has been declined"
    }.freeze

    def self.call(invitation_id:, user_id:, user_email:)
      decision = EventStore.decide(invitation: InvitationState.projection(invitation_id))
      invitation = decision.states.fetch(:invitation)
      failure = rejection(invitation, user_email)
      return failure if failure

      event = Events.invitation_accepted(invitation_id:, account_id: invitation.account_id, user_id:)
      EventStore.append(event, decision.append_condition)
      Result.success(invitation.account_id)
    rescue DcbEventStore::ConditionNotMet
      Result.failure("the invitation is no longer pending")
    end

    def self.rejection(invitation, user_email)
      return Result.failure("the invitation was not found") unless invitation
      return Result.failure("the invitation was not sent to this user's email") unless sent_to?(invitation, user_email)

      settled_rejection(invitation.status)
    end
    private_class_method :rejection

    def self.settled_rejection(status)
      message = SETTLED_REJECTIONS[status]
      Result.failure(message) if message
    end
    private_class_method :settled_rejection

    def self.sent_to?(invitation, user_email)
      invitation.email == user_email.to_s.strip.downcase
    end
    private_class_method :sent_to?
  end
end
