# Decision-model projection answering "which user has this (normalised)
# email?": the user id of the UserRegistered event tagged `user_email:{email}`,
# or nil. Used by commands that address a user by email.
module Identity
  module UserByEmail
    extend self

    def projection(email)
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: { "UserRegistered" => ->(_state, event) { event.data.fetch(:user_id) } },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(event_types: "UserRegistered", tags: "user_email:#{email}")
        )
      )
    end
  end
end
