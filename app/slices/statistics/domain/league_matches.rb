# The statistics slice's own fold of the matches slice's MatchRegistered
# events (the cross-slice contract — docs/ARCHITECTURE.md): the league's
# matches in registration order, oldest first, as Statistics::Match values.
module Statistics
  module LeagueMatches
    extend self

    def for_league(league_id)
      EventStore.project(projection(league_id))
    end

    def projection(league_id)
      DcbEventStore::Projection.new(
        initial_state: [],
        handlers: { "MatchRegistered" => ->(state, event) { state + [ match(event) ] } },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(event_types: "MatchRegistered", tags: "league:#{league_id}")
        )
      )
    end

    def match(event)
      Match.new(
        home_player_ids: event.data.fetch(:home_player_ids), away_player_ids: event.data.fetch(:away_player_ids),
        home_score: event.data.fetch(:home_score), away_score: event.data.fetch(:away_score)
      )
    end
  end
end
