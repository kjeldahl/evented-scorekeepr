# Decision-model projection answering "who is the super admin?". There is at
# most one (docs/DOMAIN.md § Super admin), so it queries the global
# `super_admin` tag and folds to the granted user's id (nil while nobody is
# super admin). Revocation is deliberately deferred, so the fold never
# returns to nil.
module Identity
  module SuperAdminStatus
    extend self

    def projection
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: { "SuperAdminGranted" => ->(_state, event) { event.data.fetch(:user_id) } },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(event_types: "SuperAdminGranted", tags: "super_admin")
        )
      )
    end
  end
end
