# Decision-model and form projection over a single multiplayer match, folded
# from its own MultiplayerMatchRegistered (and any later
# MultiplayerMatchResultCorrected / MultiplayerMatchDeleted) by the match tag.
# Returns nil until the match exists; once registered it is a Details value
# carrying the fixed player list and the current scores. A
# MultiplayerMatchDeleted flips the deleted? flag rather than dropping the
# state, so the transition stays observable; `find` maps a deleted match
# back to nil at the read boundary.
module Matches
  module MultiplayerMatchDetails
    Details = Data.define(:match_id, :league_id, :account_id, :player_ids,
                          :player_scores, :deleted) do
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
          "MultiplayerMatchRegistered" => ->(_state, event) { registered(match_id, event) },
          "MultiplayerMatchResultCorrected" => ->(state, event) {
            state&.with(player_scores: event.data.fetch(:player_scores))
          },
          "MultiplayerMatchDeleted" => ->(state, _event) { state&.with(deleted: true) }
        },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(
            event_types: %w[MultiplayerMatchRegistered MultiplayerMatchResultCorrected MultiplayerMatchDeleted],
            tags: "match:#{match_id}"
          )
        )
      )
    end

    def registered(match_id, event)
      Details.new(
        match_id:, league_id: event.data.fetch(:league_id),
        account_id: event.data.fetch(:account_id),
        player_ids: event.data.fetch(:player_ids),
        player_scores: event.data.fetch(:player_scores),
        deleted: false
      )
    end
  end
end