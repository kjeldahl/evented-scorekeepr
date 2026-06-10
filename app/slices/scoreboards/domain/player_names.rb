# Display names for a set of players, resolved by folding the identity
# slice's UserRegistered events (the cross-slice contract —
# docs/ARCHITECTURE.md). One narrow query item per user keeps the read tight.
module Scoreboards
  module PlayerNames
    module_function

    # => { user_id => name } for every id that has a UserRegistered event.
    def for(user_ids)
      ids = user_ids.uniq
      return {} if ids.empty?

      EventStore.project(projection(ids))
    end

    def projection(user_ids)
      DcbEventStore::Projection.new(
        initial_state: {},
        handlers: {
          "UserRegistered" => ->(state, event) { state.merge(event.data[:user_id] => event.data[:name]) }
        },
        query: DcbEventStore::Query.new(user_ids.map { |user_id| query_item(user_id) })
      )
    end

    def query_item(user_id)
      DcbEventStore::QueryItem.new(event_types: %w[UserRegistered], tags: [ "user:#{user_id}" ])
    end
  end
end
