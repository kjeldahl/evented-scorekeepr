# Decision-model projection answering "who is the super admin?". At most one
# user is super admin at a time (docs/DOMAIN.md § Super admin); the latest of
# SuperAdminGranted / SuperAdminHandedOff wins, so the state is the user id of
# the current super admin, or nil when nobody has been granted yet. The query
# spans every such event (no tag filter), so its append condition trips on any
# concurrent grant or handoff.
module Identity
  module CurrentSuperAdmin
    extend self

    def projection
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: {
          "SuperAdminGranted" => ->(_state, event) { event.data.fetch(:user_id) },
          "SuperAdminHandedOff" => ->(_state, event) { event.data.fetch(:to_user_id) }
        },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(event_types: %w[SuperAdminGranted SuperAdminHandedOff])
        )
      )
    end
  end
end
