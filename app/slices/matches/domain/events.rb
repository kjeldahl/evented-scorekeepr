# The matches slice's event constructors. Only this module builds the
# events the slice owns, and only this slice appends them (docs/DOMAIN.md).
# A MatchRegistered event is tagged with the match, league and account plus
# one player tag per participant, so scoreboards can fold per-player.
module Matches
  module Events
    extend self

    def match_registered(match_id:, league_id:, account_id:, home_player_ids:, away_player_ids:,
                         home_score:, away_score:, registered_by_user_id:)
      DcbEventStore::Event.new(
        type: "MatchRegistered",
        data: { match_id:, league_id:, account_id:, home_player_ids:, away_player_ids:,
                home_score:, away_score:, registered_by_user_id: },
        tags: [ "match:#{match_id}", "league:#{league_id}", "account:#{account_id}",
                *(home_player_ids + away_player_ids).map { |player_id| "player:#{player_id}" } ]
      )
    end
  end
end
