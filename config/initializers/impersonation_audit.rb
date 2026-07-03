# Bridges the event store to the impersonation audit trail (docs/DOMAIN.md
# § Impersonation): after every successful append, ImpersonationAudit records
# the write against the real super admin when the current request is an
# impersonation session. Root infrastructure — references no slice; the audit
# event it appends is not a slice event.
#
# to_prepare: in development the reloadable EventStore module is replaced on
# every code reload, dropping its hooks — re-register on the fresh module.
# In test/production this runs exactly once at boot.
Rails.application.config.to_prepare do
  EventStore.on_append do |events|
    ImpersonationAudit.record(events)
  end
end
