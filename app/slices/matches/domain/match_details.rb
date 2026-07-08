# Decision-model and form projection over a single match, folded from its
# own MatchRegistered (and any later MatchResultCorrected/MatchDeleted) by the
# match tag. Returns nil until the match exists; once registered it is a
# Details value carrying the fixed sides, the league/account it belongs to and
# the current score. A MatchDeleted flips the fold's `deleted?` flag rather
# than dropping the state (mirroring InvitationState's settled statuses), so
# the transition stays observable; `find` maps a deleted match back to nil at
# the read boundary. The edit form reads it to prefill the score, and
# EditMatch/DeleteMatch read it to check the actor is one of the match's
# players and the match still exists.
module Matches
  module MatchDetails
    Details = Data.define(:match_id, :league_id, :account_id, :home_player_ids, :away_player_ids,
                          :home_score, :away_score, :deleted) do
      def players = home_player_ids + away_player_ids
      def deleted? = deleted
    end

    extend self

    def find(match_id:)
      details = EventStore.project(projection(match_id:))
      details unless details&.deleted?
    end

    def projection(match_id:)
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: {
          "MatchRegistered" => ->(_state, event) { registered(match_id, event) },
          "MatchResultCorrected" => ->(state, event) { state&.with(home_score: event.data.fetch(:home_score), away_score: event.data.fetch(:away_score)) },
          "MatchDeleted" => ->(state, _event) { state&.with(deleted: true) }
        },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(
            event_types: %w[MatchRegistered MatchResultCorrected MatchDeleted], tags: "match:#{match_id}"
          )
        )
      )
    end

    def registered(match_id, event)
      Details.new(
        match_id:, league_id: event.data.fetch(:league_id), account_id: event.data.fetch(:account_id),
        home_player_ids: event.data.fetch(:home_player_ids), away_player_ids: event.data.fetch(:away_player_ids),
        home_score: event.data.fetch(:home_score), away_score: event.data.fetch(:away_score), deleted: false
      )
    end
  end
end
