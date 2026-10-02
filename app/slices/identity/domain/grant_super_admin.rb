# Grants a user read-only super admin status (docs/DOMAIN.md § Super admin).
# There is no web UI and no route — this command is invoked from cucumber
# steps, the console or seed tasks only. At most one user can be super admin:
# granting a different user is rejected. Granting the current super admin is
# an idempotent success without appending. The decision model covers every
# SuperAdminGranted event, so a lost race against any concurrent grant is
# resolved by re-deciding (success if it was the same user, rejection if not).
module Identity
  class GrantSuperAdmin
    def self.call(user_id:)
      decision = EventStore.decide(
        user: UserExistence.projection(user_id:),
        super_admin: CurrentSuperAdmin.projection
      )
      return Result.failure("the user was not found") unless decision.states.fetch(:user)

      current = decision.states.fetch(:super_admin)
      return Result.success(user_id) if current == user_id
      return Result.failure("there is already a super admin") if current

      EventStore.append(Events.super_admin_granted(user_id:), decision.append_condition)
      Result.success(user_id)
    rescue DcbEventStore::ConditionNotMet
      call(user_id:)
    end
  end
end
