# Grants a user read-only super admin status (docs/DOMAIN.md § Super admin).
# There is no web UI and no route — this command is invoked from cucumber
# steps, the console or seed tasks only. It is idempotent: granting an
# existing super admin succeeds without appending, and a lost race against a
# concurrent identical grant is equally a success (the decision model's
# query covers only this user's registration and grants, so nothing else can
# trip the condition).
module Identity
  class GrantSuperAdmin
    def self.call(user_id:)
      decision = EventStore.decide(
        user: UserExistence.projection(user_id:),
        super_admin: SuperAdminStatus.projection(user_id:)
      )
      return Result.failure("the user was not found") unless decision.states.fetch(:user)
      return Result.success(user_id) if decision.states.fetch(:super_admin)

      EventStore.append(Events.super_admin_granted(user_id:), decision.append_condition)
      Result.success(user_id)
    rescue DcbEventStore::ConditionNotMet
      Result.success(user_id)
    end
  end
end
