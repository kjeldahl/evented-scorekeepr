# frozen_string_literal: true

# Audits every write performed while a super admin is impersonating a member
# (docs/DOMAIN.md § Impersonation). Registered as an EventStore append hook
# (config/initializers/impersonation_audit.rb): after any successful append,
# if the current request is an impersonation session, it records an
# +ImpersonatedActionRecorded+ event tying the appended action(s) back to the
# real super admin. This is the "dedicated audit event per action" option the
# domain left open — chosen so the member-gated commands stay unchanged and
# impersonation-agnostic (they only ever see the impersonated member).
#
# This is root infrastructure: it references no slice, and the audit event it
# owns is not a slice event. The impersonation lifecycle events, and audit
# events themselves, are never audited — that both avoids double-recording the
# session boundaries and stops the hook recursing on its own append. Nor is
# SuperAdminHandedOff: the real super admin acts as themselves, not as the
# impersonated member.
module ImpersonationAudit
  extend self

  RECORDED_TYPE = "ImpersonatedActionRecorded"
  NON_AUDITABLE_TYPES = %w[ImpersonationStarted ImpersonationEnded ImpersonatedActionRecorded SuperAdminHandedOff].freeze

  def record(events)
    context = Current.impersonation
    return unless context

    actions = auditable(events)
    return if actions.empty?

    EventStore.append(recorded_event(context, actions))
  end

  def auditable(events)
    events.reject { |event| NON_AUDITABLE_TYPES.include?(event.type) }
  end

  def recorded_event(context, actions)
    super_admin_user_id = context.fetch(:super_admin_user_id)
    impersonation_id = context.fetch(:impersonation_id)
    DcbEventStore::Event.new(
      type: RECORDED_TYPE,
      data: {
        impersonation_id:,
        super_admin_user_id:,
        impersonated_user_id: context.fetch(:impersonated_user_id),
        actions: actions.map { |event| { type: event.type, tags: event.tags } }
      },
      tags: [ "impersonation:#{impersonation_id}", "user:#{super_admin_user_id}" ]
    )
  end
end
