# Facade for the league page: folds the league's matches, resolves the
# players' display names and computes the ranked standings rows in one call,
# so the controller stays free of domain orchestration.
module Scoreboards
  module Scoreboard
    extend self

    def rows(league)
      matches = LeagueMatches.for_league(league.league_id)
      names = PlayerNames.for(matches.flat_map(&:players))
      Standings.new(starting_points: league.starting_points, stake_percentage: league.stake_percentage,
                    match_type: league.match_type, game_type: league.game_type)
               .table(matches, names:)
    end
  end
end
