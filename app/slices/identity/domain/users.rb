# The identity slice's public reader: resolves a user_id to a user value
# object (id, name, email) or nil. ApplicationController#current_user is the
# only permitted cross-slice caller (docs/ARCHITECTURE.md).
module Identity
  module Users
    User = Data.define(:id, :name, :email)

    module_function

    def find(user_id)
      EventStore.project(projection(user_id))
    end

    def projection(user_id)
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: {
          "UserRegistered" => ->(_state, event) {
            User.new(id: event.data[:user_id], name: event.data[:name], email: event.data[:email])
          }
        },
        query: DcbEventStore::Query.new([
          DcbEventStore::QueryItem.new(event_types: %w[UserRegistered], tags: [ "user:#{user_id}" ])
        ])
      )
    end
  end
end
