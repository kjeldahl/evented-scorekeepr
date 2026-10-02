# Grants a user read-only super admin status (docs/DOMAIN.md § Super admin).
# There is no web UI and no route - this command is invoked from cucumber
# steps, the console or seed tasks only. At most one user is ever super
# admin: the decision model reads the global `super_admin` tag, so a
# different user is rejected and a concurrent grant of another user trips the
# append condition. Re-granting the current super admin is an idempotent
# success without appending.
module Identity
  class GrantSuperAdmin
    ONLY_ONE = "there can only be one super admin".freeze

    def self.call(user_id:)
      decide_and_append(user_id)
    rescue DcbEventStore::ConditionNotMet
      # Lost a race: the winning grant is now visible, so one re-decide settles it.
      decide_and_append(user_id)
    end

    def self.decide_and_append(user_id)
      decision = EventStore.decide(
        user: UserExistence.projection(user_id:),
        super_admin: SuperAdminStatus.projection
      )
      return Result.failure("the user was not found") unless decision.states.fetch(:user)

      current = decision.states.fetch(:super_admin)
      return Result.success(user_id) if current == user_id
      return Result.failure(ONLY_ONE) if current

      EventStore.append(Events.super_admin_granted(user_id:), decision.append_condition)
      Result.success(user_id)
    end
    private_class_method :decide_and_append
  end
end
