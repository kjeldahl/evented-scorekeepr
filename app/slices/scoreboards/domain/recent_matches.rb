# The recent-matches list on the league page and the TV dashboard: the 5
# most recent matches phrased the way the features do - winning side first,
# "beats" for one winner, "beat" for two, winner's score first - newest
# match first. Also formats multiplayer match lines (ranked players with
# scores). The league page renders Entry values so it can show an edit
# link to the players of a match; the TV dashboard renders the plain lines.
module Scoreboards
  module RecentMatches
    Entry = Data.define(:match_id, :line, :player_ids)

    extend self

    LIMIT = 5

    def entries(league_id, game_type: "Foosball")
      matches = LeagueMatches.for_league(league_id).last(LIMIT).reverse
      active = matches.reject { |m| m.respond_to?(:deleted?) && m.deleted? }
      # All players (including those from deleted matches) need names so the
      # `names` map covers players whose stats still appear on the scoreboard.
      all_player_ids = matches.flat_map(&:players).uniq
      names = PlayerNames.for(all_player_ids)
      active.map { |match| Entry.new(match_id: match.match_id, line: line_with_game_type(match, names, game_type),
                                     player_ids: match.players) }
    end

    def lines(league_id, game_type: "Foosball")
      entries(league_id, game_type:).map(&:line)
    end

    def line(match, names)
      case match
      when Match then head_to_head_line(match, names)
      when MultiplayerMatch then multiplayer_line(match, names)
      end
    end

    def line_with_game_type(match, names, game_type)
      case match
      when Match then head_to_head_line(match, names)
      when MultiplayerMatch then multiplayer_line(match, names, game_type)
      end
    end

    def head_to_head_line(match, names)
      "#{side(match.winners, names)} #{verb(match)} #{side(match.losers, names)} " \
        "#{match.winner_score}-#{match.loser_score}"
    end

    def multiplayer_line(match, names, game_type = "Foosball")
      config = Matches::GameType.find(game_type)
      ranking = config&.fetch(:ranking, :desc)

      ranked = match.player_ids.sort_by { |id| match.player_scores[id] }
      ranked = ranked.reverse if ranking == :desc

      ranked.map { |id| "#{names.fetch(id, id)} (#{match.player_scores[id]})" }.join(", ")
    end

    def side(player_ids, names)
      player_ids.map { |player_id| names.fetch(player_id, player_id) }.join(" and ")
    end

    def verb(match)
      match.winners.one? ? "beats" : "beat"
    end
  end
end
