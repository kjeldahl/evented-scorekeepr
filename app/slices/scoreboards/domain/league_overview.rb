# The scoreboards slice's own fold over the leagues slice's lifecycle
# events (the cross-slice contract — docs/ARCHITECTURE.md): nil until the
# league is created, then a Summary with the league's name, game type,
# scoring settings and whether it is still open. The query is scoped to
# both the league and the account, so a league can only be reached through
# its own tenant.
module Scoreboards
  module LeagueOverview
    Summary = Data.define(:league_id, :account_id, :name, :game_type,
                          :starting_points, :stake_percentage, :status) do
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
          "LeagueCreated" => ->(_state, event) { created(event) },
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

    def created(event)
      Summary.new(
        league_id: event.data[:league_id], account_id: event.data[:account_id],
        name: event.data[:name], game_type: event.data[:game_type],
        starting_points: event.data[:starting_points],
        stake_percentage: event.data[:stake_percentage], status: :open
      )
    end
  end
end
