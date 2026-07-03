# Ends an impersonation session (docs/DOMAIN.md § Impersonation). The escape
# button is only offered while a session is in effect, so the caller already
# holds the session's impersonation id and the real super admin behind it;
# no prior state is read, so the append needs no condition.
module Accounts
  class StopImpersonation
    def self.call(super_admin_user_id:, impersonation_id:)
      EventStore.append(Events.impersonation_ended(impersonation_id:, super_admin_user_id:))
      Result.success(impersonation_id)
    end
  end
end
