# The leagues slice's event constructors. Only this module builds the
# events the slice owns, and only this slice appends them (docs/DOMAIN.md).
module Leagues
  module Events
    extend self

    def league_created(league_id:, account_id:, name:, game_type:, starting_points:, stake_percentage:)
      DcbEventStore::Event.new(
        type: "LeagueCreated",
        data: { league_id:, account_id:, name:, game_type:, starting_points:, stake_percentage: },
        tags: [ "league:#{league_id}", "account:#{account_id}" ]
      )
    end

    def league_closed(league_id:, account_id:)
      DcbEventStore::Event.new(
        type: "LeagueClosed",
        data: { league_id:, account_id: },
        tags: [ "league:#{league_id}", "account:#{account_id}" ]
      )
    end
  end
end
