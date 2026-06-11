# One match phrased the way the features (and the scoreboard's recent
# matches) do: winning side first, "beats" for one winner, "beat" for two,
# winner's score first — "Alice beats Bob 21-8".
module Statistics
  module MatchLine
    extend self

    def format(match, names)
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
