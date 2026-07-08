# Monotonic per-league version for the TV dashboard's catch-up endpoint
# (fetched once on websocket (re)connect): a pure count of the league's
# lifecycle and match events (docs/DOMAIN.md § TV dashboard). Read-only —
# this fold never feeds an append condition.
module Scoreboards
  module LeagueVersion
    EVENT_TYPES = %w[LeagueCreated LeagueRenamed LeagueClosed MatchRegistered MatchResultCorrected MatchDeleted].freeze

    extend self

    def version(league_id:)
      EventStore.project(projection(league_id:))
    end

    def projection(league_id:)
      DcbEventStore::Projection.new(
        initial_state: 0,
        handlers: EVENT_TYPES.to_h { |type| [ type, ->(state, _event) { state + 1 } ] },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(event_types: EVENT_TYPES, tags: "league:#{league_id}")
        )
      )
    end
  end
end
