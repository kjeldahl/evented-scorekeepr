# The scoreboards slice's own fold of the matches slice's match events (the
# cross-slice contract - docs/ARCHITECTURE.md): the league's matches in
# registration order, oldest first, as Scoreboards::Match or
# Scoreboards::MultiplayerMatch values. A later correction replaces its
# match's score in place, and a deletion drops its match entirely - both keep
# league order so every later standing re-derives as if the change had always
# been so.
module Scoreboards
  module LeagueMatches
    extend self

    def for_league(league_id)
      EventStore.project(projection(league_id))
    end

    def projection(league_id)
      DcbEventStore::Projection.new(
        initial_state: [],
        handlers: {
          "MatchRegistered" => ->(state, event) { state + [ match(event) ] },
          "MatchResultCorrected" => ->(state, event) { correct(state, event) },
          "MatchDeleted" => ->(state, event) { delete(state, event) },
          "MultiplayerMatchRegistered" => ->(state, event) { state + [ multiplayer_match(event) ] },
          "MultiplayerMatchResultCorrected" => ->(state, event) { correct_multi(state, event) },
          "MultiplayerMatchDeleted" => ->(state, event) { delete_multi(state, event) }
        },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(
            event_types: %w[MatchRegistered MatchResultCorrected MatchDeleted
                            MultiplayerMatchRegistered MultiplayerMatchResultCorrected MultiplayerMatchDeleted],
            tags: "league:#{league_id}"
          )
        )
      )
    end

    def match(event)
      Match.new(
        match_id: event.data.fetch(:match_id),
        home_player_ids: event.data.fetch(:home_player_ids), away_player_ids: event.data.fetch(:away_player_ids),
        home_score: event.data.fetch(:home_score), away_score: event.data.fetch(:away_score)
      )
    end

    def multiplayer_match(event)
      MultiplayerMatch.new(
        match_id: event.data.fetch(:match_id),
        player_ids: event.data.fetch(:player_ids),
        player_scores: event.data.fetch(:player_scores)
      )
    end

    def correct(matches, event)
      matches.map do |match|
        next match unless match.is_a?(Match)
        next match unless match.match_id == event.data.fetch(:match_id)

        match.with(home_score: event.data.fetch(:home_score), away_score: event.data.fetch(:away_score))
      end
    end

    def correct_multi(matches, event)
      matches.map do |match|
        next match unless match.is_a?(MultiplayerMatch)
        next match unless match.match_id == event.data.fetch(:match_id)

        match.with(player_scores: event.data.fetch(:player_scores))
      end
    end

    def delete(matches, event)
      matches.reject { |match| match.is_a?(Match) && match.match_id == event.data.fetch(:match_id) }
    end

    def delete_multi(matches, event)
      matches.reject { |match| match.is_a?(MultiplayerMatch) && match.match_id == event.data.fetch(:match_id) }
    end
  end
end
