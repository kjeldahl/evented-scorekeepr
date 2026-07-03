# frozen_string_literal: true

# Impersonation world helpers (docs/DOMAIN.md § Impersonation).
#
# Public helper API:
#   impersonate(super_admin_name, member_name, account_name)  # start via the members-list button POST
#   stop_impersonating                                        # end via the layout escape button
#   audit_events(type, super_admin_name)                      # audit-trail events of a type for a super admin
module ImpersonationWorld
  def impersonate(super_admin_name, member_name, account_name)
    sign_in(super_admin_name) unless signed_in_as?(super_admin_name)
    submit_post("/accounts/#{account_id_for(account_name)}/members/#{user_id_for(member_name)}/impersonate")
  end

  # Ends the current session's impersonation. No sign-in: the acting session is
  # already the super admin's (the nav shows the impersonated member, not them).
  def stop_impersonating
    page.driver.submit :delete, "/impersonation", {}
  end

  # The audit trail is event-sourced: every impersonation session boundary and
  # audited write is tagged with the real super admin behind it.
  def audit_events(type, super_admin_name)
    query = DcbEventStore::Query.new([
      DcbEventStore::QueryItem.new(event_types: [ type ], tags: [ "user:#{user_id_for(super_admin_name)}" ])
    ])
    EventStore.read(query)
  end
end

World(ImpersonationWorld)
