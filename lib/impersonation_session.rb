# frozen_string_literal: true

# Ends an impersonation session (docs/DOMAIN.md § Impersonation). Ending is
# triggered from two slices — the accounts escape button and identity sign-out
# — so it lives in root infrastructure rather than either slice: packwerk
# forbids one slice appending another's event, and both must reach it. The
# escape button starts in the accounts slice (StartImpersonation, super-admin
# gated), but tearing a session down carries no invariant and reads nothing,
# so the append needs no condition.
#
# This owns the ImpersonationEnded event; no slice builds it.
module ImpersonationSession
  extend self

  def stop(super_admin_user_id:, impersonation_id:)
    EventStore.append(ended_event(super_admin_user_id:, impersonation_id:))
    Result.success(impersonation_id)
  end

  def ended_event(super_admin_user_id:, impersonation_id:)
    DcbEventStore::Event.new(
      type: "ImpersonationEnded",
      data: { impersonation_id:, super_admin_user_id: },
      tags: [ "impersonation:#{impersonation_id}", "user:#{super_admin_user_id}" ]
    )
  end
end
