# Read model for the super-admin all-accounts list (docs/DOMAIN.md Super
# admin section): every account in the system, sorted alphabetically by
# name. Folds all AccountCreated events by event type only (no tags),
# acceptable outside commands since this reader never feeds an append
# condition.
module Accounts
  module AllAccounts
    Summary = Data.define(:id, :name)

    extend self

    def all
      EventStore.project(projection).sort_by(&:name)
    end

    def projection
      DcbEventStore::Projection.new(
        initial_state: [],
        handlers: {
          "AccountCreated" => ->(state, event) {
            state + [ Summary.new(id: event.data.fetch(:account_id), name: event.data.fetch(:name)) ]
          }
        },
        query: DcbEventStore::Query.new(DcbEventStore::QueryItem.new(event_types: "AccountCreated"))
      )
    end
  end
end
