# frozen_string_literal: true

# Request-scoped context for impersonation (docs/ARCHITECTURE.md § Live
# updates / Impersonation). ApplicationController fills +impersonation+ from
# the session on every request; ImpersonationAudit reads it when an append
# happens so a write made while impersonating can be recorded against the
# real super admin behind it. ActiveSupport::CurrentAttributes resets this
# between requests, so it never leaks across sessions.
#
# +impersonation+ is nil when nobody is impersonating, or a Hash with keys
# :impersonation_id, :super_admin_user_id and :impersonated_user_id.
class Current < ActiveSupport::CurrentAttributes
  attribute :impersonation
end
