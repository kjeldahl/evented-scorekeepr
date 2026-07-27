# Read model resolving a league_id to its summary (settings plus whether it
# is still open) or nil when no such league exists.
module Leagues
  module League
    Summary = Data.define(:id, :account_id, :name, :game_type, :starting_points, :stake_percentage,
                          :status, :match_type) do
      def open? = status == :open
      def closed? = status == :closed
      def match_league? = match_type == "match"
      def multiplayer_league? = match_type == "multiplayer"
    end

    extend self

    def find(league_id)
      EventStore.project(projection(league_id))
    end

    def projection(league_id)
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: {
          "LeagueCreated" => ->(_state, event) { created(event) },
          "LeagueRenamed" => ->(state, event) { state&.with(name: event.data.fetch(:name)) },
          "LeagueClosed" => ->(state, _event) { state&.with(status: :closed) }
        },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(
            event_types: %w[LeagueCreated LeagueRenamed LeagueClosed], tags: "league:#{league_id}"
          )
        )
      )
    end

    def created(event)
      Summary.new(
        id: event.data.fetch(:league_id), account_id: event.data.fetch(:account_id),
        name: event.data.fetch(:name), game_type: event.data.fetch(:game_type),
        starting_points: event.data.fetch(:starting_points),
        stake_percentage: event.data.fetch(:stake_percentage), status: :open,
        match_type: event.data.fetch(:match_type, "match")
      )
    end
  end
end
