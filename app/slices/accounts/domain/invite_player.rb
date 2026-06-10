# Invites a player into an account by email. Only members can invite; the
# membership decision model's append condition guards the invariant against
# concurrent appends.
module Accounts
  class InvitePlayer
    def self.call(account_id:, email:, invited_by_user_id:)
      # Presence only — Events.player_invited normalises the email for data and tags.
      return Result.failure("email is required") unless email.to_s.match?(/\S/)

      decision = EventStore.decide(member: Membership.projection(account_id:, user_id: invited_by_user_id))
      return Result.failure("only members can invite players") unless decision.states.fetch(:member)

      append_invitation(decision, account_id, email, invited_by_user_id)
    rescue DcbEventStore::ConditionNotMet
      Result.failure("the account changed while you were working — please retry")
    end

    def self.append_invitation(decision, account_id, email, invited_by_user_id)
      invitation_id = SecureRandom.uuid
      event = Events.player_invited(invitation_id:, account_id:, email:, invited_by_user_id:)
      EventStore.append(event, decision.append_condition)
      Result.success(invitation_id)
    end
    private_class_method :append_invitation
  end
end
