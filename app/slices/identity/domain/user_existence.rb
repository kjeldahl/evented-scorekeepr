# Decision-model projection answering "does this user exist?". Folded over
# UserRegistered events tagged with the user id, so commands that require an
# existing user can carry the read in their append condition.
module Identity
  module UserExistence
    extend self

    def projection(user_id:)
      DcbEventStore::Projection.new(
        initial_state: false,
        handlers: { "UserRegistered" => ->(_state, _event) { true } },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(event_types: "UserRegistered", tags: "user:#{user_id}")
        )
      )
    end
  end
end
