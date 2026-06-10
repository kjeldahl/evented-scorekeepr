# Read model resolving an account_id to its summary (id, name, owner) or
# nil when no such account exists.
module Accounts
  module Account
    Summary = Data.define(:id, :name, :owner_user_id)

    module_function

    def find(account_id)
      EventStore.project(projection(account_id))
    end

    def projection(account_id)
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: {
          "AccountCreated" => ->(_state, event) {
            Summary.new(id: event.data[:account_id], name: event.data[:name],
                        owner_user_id: event.data[:owner_user_id])
          }
        },
        query: DcbEventStore::Query.new([
          DcbEventStore::QueryItem.new(event_types: %w[AccountCreated], tags: [ "account:#{account_id}" ])
        ])
      )
    end
  end
end
