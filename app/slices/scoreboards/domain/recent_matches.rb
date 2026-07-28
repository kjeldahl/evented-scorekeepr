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

    def entries(league_id, game_type:)
      matches = LeagueMatches.for_league(league_id).last(LIMIT).reverse
      names = PlayerNames.for(matches.flat_map(&:players))
      matches.map { |match| Entry.new(match_id: match.match_id, line: line(match, names, game_type),
                                      player_ids: match.players) }
    end

    def lines(league_id, game_type:)
      entries(league_id, game_type:).map(&:line)
    end

    # The game type only reaches the multiplayer phrasing, which ranks by it;
    # a head-to-head line reads the same in every game.
    def line(match, names, game_type)
      case match
      when Match then head_to_head_line(match, names)
      when MultiplayerMatch then multiplayer_line(match, names, game_type)
      end
    end

    def head_to_head_line(match, names)
      "#{side(match.winners, names)} #{verb(match)} #{side(match.losers, names)} " \
        "#{match.winner_score}-#{match.loser_score}"
    end

    def multiplayer_line(match, names, game_type)
      ranked = match.player_ids.sort_by { |id| score_of(match, id) }
      ranked = ranked.reverse if MultiplayerGameType.find(game_type).fetch(:ranking) == :desc

      ranked.map { |id| "#{names.fetch(id, id)} (#{score_of(match, id)})" }.join(", ")
    end

    # Player ids are strings while the stored scores round-trip out of the
    # event store symbol-keyed, so the score is always read by symbol (the
    # same boundary Standings applies). Every player of a multiplayer match
    # has a score; a missing one is a corrupt registration, not a zero.
    def score_of(match, player_id)
      match.player_scores.fetch(player_id.to_sym)
    end

    def side(player_ids, names)
      player_ids.map { |player_id| names.fetch(player_id, player_id) }.join(" and ")
    end

    def verb(match)
      match.winners.one? ? "beats" : "beat"
    end
  end
end
