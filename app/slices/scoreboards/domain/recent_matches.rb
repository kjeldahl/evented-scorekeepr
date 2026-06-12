# The recent-matches list on the league page and the TV dashboard: the 5
# most recent matches phrased the way the features do — winning side first,
# "beats" for one winner, "beat" for two, winner's score first — newest
# match first.
module Scoreboards
  module RecentMatches
    extend self

    LIMIT = 5

    def lines(league_id)
      matches = LeagueMatches.for_league(league_id).last(LIMIT).reverse
      names = PlayerNames.for(matches.flat_map(&:players))
      matches.map { |match| line(match, names) }
    end

    def line(match, names)
      "#{side(match.winners, names)} #{verb(match)} #{side(match.losers, names)} " \
        "#{match.winner_score}-#{match.loser_score}"
    end

    def side(player_ids, names)
      player_ids.map { |player_id| names.fetch(player_id, player_id) }.join(" and ")
    end

    def verb(match)
      match.winners.one? ? "beats" : "beat"
    end
  end
end
