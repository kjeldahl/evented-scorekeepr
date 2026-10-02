# The statistics slice's own super admin fold: a user is a super admin iff
# latest SuperAdminGranted/SuperAdminRevoked event (identity slice) tagged with their
# user id is a grant. Used only by the view gate — read access without membership;
# commands never consult it. Other slices duplicate this fold over the same
# event — events are the only cross-slice contract (docs/ARCHITECTURE.md).
module Statistics
  module SuperAdmin
    extend self

    def super_admin?(user_id:)
      EventStore.project(projection(user_id:))
    end

    def projection(user_id:)
      DcbEventStore::Projection.new(
        initial_state: false,
        handlers: {
          "SuperAdminGranted" => ->(_state, _event) { true },
          "SuperAdminRevoked" => ->(_state, _event) { false }
        },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(event_types: %w[SuperAdminGranted SuperAdminRevoked], tags: "user:#{user_id}")
        )
      )
    end
  end
end
