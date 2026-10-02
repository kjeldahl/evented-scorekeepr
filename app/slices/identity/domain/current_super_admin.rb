# Decision-model projection answering "who is the super admin?". At most one
# user may be super admin at a time (docs/DOMAIN.md § Super admin), so the
# query spans every SuperAdminGranted/SuperAdminRevoked event (no tag filter).
# The state is the current holder's user id (the first grant wins while held;
# revoking the holder clears it), or nil when nobody holds it. Its append
# condition therefore trips on any concurrent grant or revocation.
module Identity
  module CurrentSuperAdmin
    extend self

    def holder
      EventStore.project(projection)
    end

    def projection
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: {
          "SuperAdminGranted" => ->(state, event) { state || event.data.fetch(:user_id) },
          "SuperAdminRevoked" => ->(state, event) { state unless state == event.data.fetch(:user_id) }
        },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(event_types: %w[SuperAdminGranted SuperAdminRevoked])
        )
      )
    end
  end
end
