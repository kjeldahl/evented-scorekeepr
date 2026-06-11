# The identity slice's public reader: resolves a user_id to a user value
# object (id, name, email, handle) or nil. ApplicationController#current_user
# is the only permitted cross-slice caller (docs/ARCHITECTURE.md).
module Identity
  module Users
    User = Data.define(:id, :name, :email, :handle)

    extend self

    def find(user_id)
      EventStore.project(projection(user_id))
    end

    def projection(user_id)
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: {
          "UserRegistered" => ->(_state, event) {
            User.new(id: event.data.fetch(:user_id), name: event.data.fetch(:name),
                     email: event.data.fetch(:email), handle: nil)
          },
          "UserHandleSet" => ->(state, event) { state&.with(handle: event.data.fetch(:handle)) }
        },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(event_types: %w[UserRegistered UserHandleSet], tags: "user:#{user_id}")
        )
      )
    end
  end
end
