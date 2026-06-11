# Decision-model projection answering "is this user already a super admin?".
# Super admin status is true iff at least one SuperAdminGranted event exists
# for the user (docs/DOMAIN.md § Super admin) — revocation is deliberately
# deferred, so the fold never returns to false.
module Identity
  module SuperAdminStatus
    extend self

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
