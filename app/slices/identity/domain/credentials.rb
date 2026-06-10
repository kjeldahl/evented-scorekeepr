# Read model resolving a normalised email to the registered credentials
# (user_id + password_digest), or nil when the email is unknown.
module Identity
  module Credentials
    extend self

    def find_by_email(email)
      EventStore.project(projection(email))
    end

    def projection(email)
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: {
          "UserRegistered" => ->(_state, event) {
            { user_id: event.data.fetch(:user_id), password_digest: event.data.fetch(:password_digest) }
          }
        },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(event_types: "UserRegistered", tags: "user_email:#{email}")
        )
      )
    end
  end
end
