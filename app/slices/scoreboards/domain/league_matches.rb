# The scoreboards slice's own fold of the matches slice's MatchRegistered
# events (the cross-slice contract — docs/ARCHITECTURE.md): the league's
# matches in registration order, oldest first, as Scoreboards::Match values.
module Scoreboards
  module LeagueMatches
    module_function

    def for_league(league_id)
      EventStore.project(projection(league_id))
    end

    def projection(league_id)
      DcbEventStore::Projection.new(
        initial_state: [],
        handlers: { "MatchRegistered" => ->(state, event) { state + [ match(event) ] } },
        query: DcbEventStore::Query.new([
          DcbEventStore::QueryItem.new(event_types: %w[MatchRegistered], tags: [ "league:#{league_id}" ])
        ])
      )
    end

    def match(event)
      Match.new(
        home_player_ids: event.data[:home_player_ids], away_player_ids: event.data[:away_player_ids],
        home_score: event.data[:home_score], away_score: event.data[:away_score]
      )
    end
  end
end
