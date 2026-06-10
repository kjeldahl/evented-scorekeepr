# The matches slice's own fold over the leagues slice's lifecycle events
# (the cross-slice contract — docs/ARCHITECTURE.md): nil until the league is
# created, then a Summary whose status flips to :closed on LeagueClosed.
# The query is scoped to both the league and the account so a league can
# only be reached through its own tenant, and the append condition built
# from it makes registering a match race-free against a concurrent close.
module Matches
  module League
    Summary = Data.define(:name, :status) do
      def open? = status == :open
      def closed? = status == :closed
    end

    module_function

    def find(league_id:, account_id:)
      EventStore.project(projection(league_id:, account_id:))
    end

    def projection(league_id:, account_id:)
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: {
          "LeagueCreated" => ->(_state, event) { Summary.new(name: event.data[:name], status: :open) },
          "LeagueClosed" => ->(state, _event) { state&.with(status: :closed) }
        },
        query: DcbEventStore::Query.new([
          DcbEventStore::QueryItem.new(
            event_types: %w[LeagueCreated LeagueClosed],
            tags: [ "league:#{league_id}", "account:#{account_id}" ]
          )
        ])
      )
    end
  end
end
