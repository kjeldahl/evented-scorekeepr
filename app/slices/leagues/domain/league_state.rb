# Decision-model projection over one league's lifecycle: :none until it is
# created, :open afterwards, :closed once a LeagueClosed event is folded.
# The query is scoped to both the league and the account so a league can
# only be acted on through its own tenant, and the append condition built
# from it makes closing race-free.
module Leagues
  module LeagueState
    module_function

    def projection(league_id:, account_id:)
      DcbEventStore::Projection.new(
        initial_state: :none,
        handlers: {
          "LeagueCreated" => ->(_state, _event) { :open },
          "LeagueClosed" => ->(_state, _event) { :closed }
        },
        query: DcbEventStore::Query.new([
          DcbEventStore::QueryItem.new(
            event_types: %w[LeagueCreated LeagueClosed],
            tags: [ "league:#{league_id}", "account:#{account_id}" ]
          )
        ])
      )
    end
  end
end
