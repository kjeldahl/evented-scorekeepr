# Decision-model and form projection over a single match, folded from its
# own MatchRegistered (and any later MatchResultCorrected) by the match tag.
# Returns nil until the match exists, then a Details value carrying the
# fixed sides, the league/account it belongs to and the current score. The
# edit form reads it to prefill the score, and EditMatch reads it to check
# the editor is one of the match's players before correcting it.
module Matches
  module MatchDetails
    Details = Data.define(:match_id, :league_id, :account_id, :home_player_ids, :away_player_ids,
                          :home_score, :away_score) do
      def players = home_player_ids + away_player_ids
    end

    extend self

    def find(match_id:)
      EventStore.project(projection(match_id:))
    end

    def projection(match_id:)
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: {
          "MatchRegistered" => ->(_state, event) { registered(match_id, event) },
          "MatchResultCorrected" => ->(state, event) { state&.with(home_score: event.data.fetch(:home_score), away_score: event.data.fetch(:away_score)) }
        },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(
            event_types: %w[MatchRegistered MatchResultCorrected], tags: "match:#{match_id}"
          )
        )
      )
    end

    def registered(match_id, event)
      Details.new(
        match_id:, league_id: event.data.fetch(:league_id), account_id: event.data.fetch(:account_id),
        home_player_ids: event.data.fetch(:home_player_ids), away_player_ids: event.data.fetch(:away_player_ids),
        home_score: event.data.fetch(:home_score), away_score: event.data.fetch(:away_score)
      )
    end
  end
end
