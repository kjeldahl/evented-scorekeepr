# This slice's own super admin fold: latest wins over the identity slice's
# SuperAdminGranted (true) and SuperAdminHandedOff (true for the recipient,
# false for the sender) events tagged with the user id. Used only by the view
# gate; commands never consult it, bar impersonation start in accounts. Other
# slices duplicate this fold — events are the only cross-slice contract.
module Scoreboards
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
          "SuperAdminHandedOff" => ->(_state, event) { event.data.fetch(:to_user_id) == user_id }
        },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(event_types: %w[SuperAdminGranted SuperAdminHandedOff], tags: "user:#{user_id}")
        )
      )
    end
  end
end
