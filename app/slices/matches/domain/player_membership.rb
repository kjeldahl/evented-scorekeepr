# Decision-model projection over the membership of a match's players: folds
# the accounts slice's events (the cross-slice contract) into the list of
# player ids that are members of the account. One narrow query item per
# player (account + user tags) keeps the append condition tight.
module Matches
  module PlayerMembership
    extend self

    def projection(account_id:, player_ids:)
      DcbEventStore::Projection.new(
        initial_state: [],
        handlers: {
          "AccountCreated" => ->(state, event) { state | [ event.data.fetch(:owner_user_id) ] },
          "InvitationAccepted" => ->(state, event) { state | [ event.data.fetch(:user_id) ] }
        },
        query: DcbEventStore::Query.new(player_ids.map { |player_id| query_item(account_id, player_id) })
      )
    end

    def query_item(account_id, player_id)
      DcbEventStore::QueryItem.new(
        event_types: %w[AccountCreated InvitationAccepted],
        tags: [ "account:#{account_id}", "user:#{player_id}" ]
      )
    end
  end
end
