# Hands super admin status from the current super admin to another registered
# user, identified by email (docs/DOMAIN.md § Super admin). Checks run in
# order — sender is the super admin, sender has re-authenticated (the caller
# verifies the password; the command never sees it), recipient exists,
# recipient is someone else — and the first failure is reported. Rejections
# append nothing. When the sender is impersonating, the session's
# ImpersonationEnded is appended in the same write, so the handoff and the end
# of impersonation are atomic. The decision model covers the current super
# admin and the recipient's registration, so a concurrent handoff is caught.
module Identity
  class HandOffSuperAdmin
    NOT_SUPER_ADMIN = "only the super admin can hand off super admin status"
    ALREADY_SUPER_ADMIN = "you are already the super admin"

    def self.call(from_user_id:, reauthenticated:, to_email:, impersonation_id:)
      decision = EventStore.decide(
        super_admin: CurrentSuperAdmin.projection,
        recipient: Credentials.projection(to_email.to_s.strip.downcase)
      )
      failure = rejection(decision.states, from_user_id:, reauthenticated:)
      return failure if failure

      to_user_id = decision.states.fetch(:recipient).fetch(:user_id)
      to_append = events(from_user_id:, to_user_id:, impersonation_id:)
      EventStore.append(to_append, decision.append_condition)
      Result.success(to_user_id)
    rescue DcbEventStore::ConditionNotMet
      call(from_user_id:, reauthenticated:, to_email:, impersonation_id:)
    end

    def self.rejection(states, from_user_id:, reauthenticated:)
      return Result.failure(NOT_SUPER_ADMIN) unless states.fetch(:super_admin) == from_user_id
      return Result.failure(AuthenticateUser::INVALID_CREDENTIALS) unless reauthenticated

      recipient = states.fetch(:recipient)
      return Result.failure("the user was not found") unless recipient

      Result.failure(ALREADY_SUPER_ADMIN) if recipient.fetch(:user_id) == from_user_id
    end
    private_class_method :rejection

    def self.events(from_user_id:, to_user_id:, impersonation_id:)
      list = [ Events.super_admin_handed_off(from_user_id:, to_user_id:) ]
      list << ImpersonationSession.ended_event(super_admin_user_id: from_user_id, impersonation_id:) if impersonation_id
      list
    end
    private_class_method :events
  end
end
