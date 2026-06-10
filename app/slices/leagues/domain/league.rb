# Read model resolving a league_id to its summary (settings plus whether it
# is still open) or nil when no such league exists.
module Leagues
  module League
    Summary = Data.define(:id, :account_id, :name, :game_type, :starting_points, :stake_percentage, :status) do
      def open? = status == :open
      def closed? = status == :closed
    end

    module_function

    def find(league_id)
      EventStore.project(projection(league_id))
    end

    def projection(league_id)
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: {
          "LeagueCreated" => ->(_state, event) { created(event) },
          "LeagueClosed" => ->(state, _event) { state&.with(status: :closed) }
        },
        query: DcbEventStore::Query.new([
          DcbEventStore::QueryItem.new(event_types: %w[LeagueCreated LeagueClosed], tags: [ "league:#{league_id}" ])
        ])
      )
    end

    def created(event)
      Summary.new(
        id: event.data[:league_id], account_id: event.data[:account_id],
        name: event.data[:name], game_type: event.data[:game_type],
        starting_points: event.data[:starting_points],
        stake_percentage: event.data[:stake_percentage], status: :open
      )
    end
  end
end
