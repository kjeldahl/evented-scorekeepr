# Starts a super admin's impersonation session against an account member
# (docs/DOMAIN.md § Impersonation). This is the one command that consults
# super admin status; every other member-gated command stays membership-only
# and never looks at it. The decision model reads the actor's super admin
# grant and the target's membership, and its append condition makes the write
# race-free against a concurrent grant change or the target leaving.
module Accounts
  class StartImpersonation
    def self.call(super_admin_user_id:, account_id:, impersonated_user_id:)
      decision = EventStore.decide(
        super_admin: SuperAdmin.projection(user_id: super_admin_user_id),
        member: Membership.projection(account_id:, user_id: impersonated_user_id)
      )
      failure = rejection(decision.states)
      return failure if failure

      append_started(decision, super_admin_user_id:, account_id:, impersonated_user_id:)
    rescue DcbEventStore::ConditionNotMet
      Result.failure("the account changed while you were working — please retry")
    end

    def self.rejection(states)
      return Result.failure("only super admins can impersonate players") unless states.fetch(:super_admin)

      Result.failure("only members can be impersonated") unless states.fetch(:member)
    end
    private_class_method :rejection

    def self.append_started(decision, super_admin_user_id:, account_id:, impersonated_user_id:)
      impersonation_id = SecureRandom.uuid
      event = Events.impersonation_started(
        impersonation_id:, super_admin_user_id:, impersonated_user_id:, account_id:
      )
      EventStore.append(event, decision.append_condition)
      Result.success(impersonation_id)
    end
    private_class_method :append_started
  end
end
