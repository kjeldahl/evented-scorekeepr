# Read model for the account page's leagues section. The leagues slice owns
# LeagueCreated/LeagueClosed; this slice folds those events itself (events
# are the only cross-slice contract — docs/ARCHITECTURE.md) to list each
# league's name and whether it is still open.
module Accounts
  module AccountLeagues
    League = Data.define(:league_id, :name, :open) do
      def open? = open
    end

    extend self

    def for_account(account_id)
      EventStore.project(projection(account_id)).values
    end

    def projection(account_id)
      DcbEventStore::Projection.new(
        initial_state: {},
        handlers: {
          "LeagueCreated" => ->(state, event) { state.merge(created_league(event)) },
          "LeagueClosed" => ->(state, event) { close_league(state, event) }
        },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(
            event_types: %w[LeagueCreated LeagueClosed],
            tags: "account:#{account_id}"
          )
        )
      )
    end

    def created_league(event)
      league_id = event.data.fetch(:league_id)
      { league_id => League.new(league_id:, name: event.data.fetch(:name), open: true) }
    end

    def close_league(state, event)
      league_id = event.data.fetch(:league_id)
      league = state[league_id]
      league ? state.merge(league_id => league.with(open: false)) : state
    end
  end
end
