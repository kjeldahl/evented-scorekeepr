# Accepts an invitation, making the accepting user a member of the account.
# Only the signed-in user whose email matches the invitation may accept, and
# an invitation can be accepted only once — the single acceptance is
# enforced by the invitation decision model's append condition, so two
# concurrent accepts cannot both succeed.
module Accounts
  class AcceptInvitation
    def self.call(invitation_id:, user_id:, user_email:)
      decision = EventStore.decide(invitation: InvitationState.projection(invitation_id))
      invitation = decision.states[:invitation]
      failure = rejection(invitation, user_email)
      return failure if failure

      event = Events.invitation_accepted(invitation_id:, account_id: invitation.account_id, user_id:)
      EventStore.append([ event ], decision.append_condition)
      Result.success(invitation.account_id)
    rescue DcbEventStore::ConditionNotMet
      Result.failure("the invitation has already been accepted")
    end

    def self.rejection(invitation, user_email)
      return Result.failure("the invitation was not found") unless invitation
      return Result.failure("the invitation was not sent to this user's email") unless sent_to?(invitation, user_email)

      Result.failure("the invitation has already been accepted") if invitation.accepted
    end
    private_class_method :rejection

    def self.sent_to?(invitation, user_email)
      invitation.email == user_email.to_s.strip.downcase
    end
    private_class_method :sent_to?
  end
end
