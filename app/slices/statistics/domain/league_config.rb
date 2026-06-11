# The statistics slice's own fold over the leagues slice's LeagueCreated
# event (the cross-slice contract — docs/ARCHITECTURE.md): nil until the
# league is created, then the league's name and scoring configuration. The
# query is scoped to both the league and the account, so a league's player
# pages can only be reached through their own tenant.
module Statistics
  module LeagueConfig
    Config = Data.define(:league_id, :account_id, :name, :starting_points, :stake_percentage)

    extend self

    def find(league_id:, account_id:)
      EventStore.project(projection(league_id:, account_id:))
    end

    def projection(league_id:, account_id:)
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: { "LeagueCreated" => ->(_state, event) { config(event) } },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(
            event_types: %w[LeagueCreated],
            tags: [ "league:#{league_id}", "account:#{account_id}" ]
          )
        )
      )
    end

    def config(event)
      Config.new(
        league_id: event.data.fetch(:league_id), account_id: event.data.fetch(:account_id),
        name: event.data.fetch(:name), starting_points: event.data.fetch(:starting_points),
        stake_percentage: event.data.fetch(:stake_percentage)
      )
    end
  end
end
