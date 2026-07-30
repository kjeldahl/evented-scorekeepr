# The matches slice's own fold over the leagues slice's lifecycle events
# (the cross-slice contract — docs/ARCHITECTURE.md): nil until the league is
# created, then a Summary whose status flips to :closed on LeagueClosed.
# The query is scoped to both the league and the account so a league can
# only be reached through its own tenant, and the append condition built
# from it makes registering a match race-free against a concurrent close.
module Matches
  module League
    Summary = Data.define(:name, :status, :match_type, :game_type) do
      def open? = status == :open
      def closed? = status == :closed
      def match_league? = match_type == "match"
      def multiplayer_league? = match_type == "multiplayer"

      # How many form rows to show: capped by game type max and the supplied
      # member count so that every row can legally be filled.
      def row_limit(member_count)
        if multiplayer_league?
          [ GameType.find(game_type)[:max_players], member_count ].min
        else
          member_count
        end
      end
    end

    extend self

    def find(league_id:, account_id:)
      EventStore.project(projection(league_id:, account_id:))
    end

    def projection(league_id:, account_id:)
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: {
          "LeagueCreated" => ->(_state, event) {
            Summary.new(name: event.data.fetch(:name), status: :open,
                        match_type: event.data.fetch(:match_type, "match"),
                        game_type: event.data.fetch(:game_type))
          },
          "LeagueRenamed" => ->(state, event) { state&.with(name: event.data.fetch(:name)) },
          "LeagueClosed" => ->(state, _event) { state&.with(status: :closed) }
        },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(
            event_types: %w[LeagueCreated LeagueRenamed LeagueClosed],
            tags: [ "league:#{league_id}", "account:#{account_id}" ]
          )
        )
      )
    end
  end
end
