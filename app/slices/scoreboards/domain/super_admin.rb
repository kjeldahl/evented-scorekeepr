# The scoreboards slice's own super admin fold: a user is a super admin iff
# at least one SuperAdminGranted event (identity slice) is tagged with their
# user id. Used only by the view gate — read access without membership;
# commands never consult it. Other slices duplicate this fold over the same
# event — events are the only cross-slice contract (docs/ARCHITECTURE.md).
module Scoreboards
  module SuperAdmin
    extend self

    def super_admin?(user_id:)
      EventStore.project(projection(user_id:))
    end

    def projection(user_id:)
      DcbEventStore::Projection.new(
        initial_state: false,
        handlers: { "SuperAdminGranted" => ->(_state, _event) { true } },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(event_types: "SuperAdminGranted", tags: "user:#{user_id}")
        )
      )
    end
  end
end
