# Decision-model projection answering "who is the super admin?". At most one
# user may ever be super admin (docs/DOMAIN.md § Super admin), so the query
# spans every SuperAdminGranted event (no tag filter) and the state is the
# user id of the first grant, or nil when nobody has been granted yet. Its
# append condition therefore trips on any concurrent grant, for any user.
module Identity
  module CurrentSuperAdmin
    extend self

    def projection
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: { "SuperAdminGranted" => ->(state, event) { state || event.data.fetch(:user_id) } },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(event_types: "SuperAdminGranted")
        )
      )
    end
  end
end
