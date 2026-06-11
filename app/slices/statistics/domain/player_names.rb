# Display names for a set of players — the handle when one is set, else the
# registered name — resolved by folding the identity slice's
# UserRegistered/UserHandleSet events (the cross-slice contract —
# docs/ARCHITECTURE.md; handle events come after the registration, so the
# latest folded value per user wins). One narrow query item per user keeps
# the read tight.
module Statistics
  module PlayerNames
    extend self

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
          "UserRegistered" => ->(state, event) { state.merge(event.data.fetch(:user_id) => event.data.fetch(:name)) },
          "UserHandleSet" => ->(state, event) { state.merge(event.data.fetch(:user_id) => event.data.fetch(:handle)) }
        },
        query: DcbEventStore::Query.new(user_ids.map { |user_id| query_item(user_id) })
      )
    end

    def query_item(user_id)
      DcbEventStore::QueryItem.new(event_types: %w[UserRegistered UserHandleSet], tags: "user:#{user_id}")
    end
  end
end
