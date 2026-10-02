# Hands super admin status from the current super admin to another registered
# user, identified by email (docs/DOMAIN.md § Super admin). Checks run in
# order — sender is the super admin, password re-authenticates the sender,
# recipient exists — and the first failure is reported. Handing off to oneself
# appends no handoff event. When the sender is impersonating, the session's
# ImpersonationEnded is appended in the same write (alone on a self-handoff),
# so the handoff and the end of impersonation are atomic. The decision model covers the current super
# admin and the recipient's registration, so a concurrent handoff is caught.
module Identity
  class HandOffSuperAdmin
    NOT_SUPER_ADMIN = "only the super admin can hand off super admin status"

    def self.call(from_user_id:, password:, to_email:, impersonation_id:)
      decision = EventStore.decide(
        super_admin: CurrentSuperAdmin.projection,
        recipient: Credentials.projection(to_email.to_s.strip.downcase)
      )
      failure = rejection(decision.states, from_user_id:, password:)
      return failure if failure

      to_user_id = decision.states.fetch(:recipient).fetch(:user_id)
      to_append = events(from_user_id:, to_user_id:, impersonation_id:)
      EventStore.append(to_append, decision.append_condition) unless to_append.empty?
      Result.success(to_user_id)
    rescue DcbEventStore::ConditionNotMet
      call(from_user_id:, password:, to_email:, impersonation_id:)
    end

    def self.rejection(states, from_user_id:, password:)
      return Result.failure(NOT_SUPER_ADMIN) unless states.fetch(:super_admin) == from_user_id
      return Result.failure(AuthenticateUser::INVALID_CREDENTIALS) unless password_matches?(from_user_id, password)

      Result.failure("the user was not found") unless states.fetch(:recipient)
    end
    private_class_method :rejection

    def self.password_matches?(user_id, password)
      AuthenticateUser.call(email: Users.find(user_id).email, password:).success?
    end
    private_class_method :password_matches?

    def self.events(from_user_id:, to_user_id:, impersonation_id:)
      list = []
      list << Events.super_admin_handed_off(from_user_id:, to_user_id:) unless to_user_id == from_user_id
      list << ImpersonationSession.ended_event(super_admin_user_id: from_user_id, impersonation_id:) if impersonation_id
      list
    end
    private_class_method :events
  end
end
