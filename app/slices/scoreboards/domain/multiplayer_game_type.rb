# Frozen code constant mapping game_type strings to config: ranking direction,
# min/max players, and an implicit mode (:match or :multiplayer). Unknown game
# types default to desc ranking, 2-4 players (matching the default match league
# constraints). (docs/DOMAIN.md)
module Scoreboards
  module MultiplayerGameType
    DEFAULT = { ranking: :desc, min_players: 2, max_players: 4 }.freeze

    CONFIG = {
      "Foosball"     => { ranking: :desc, min_players: 2, max_players: 4 }.freeze,
      "Table Tennis" => { ranking: :desc, min_players: 2, max_players: 4 }.freeze,
      "Golf"         => { ranking: :asc, min_players: 1, max_players: 8 }.freeze,
      "Norsk Rummy"  => { ranking: :asc, min_players: 2, max_players: 8 }.freeze
    }.freeze

    extend self

    def find(game_type)
      CONFIG.fetch(game_type, DEFAULT)
    end

    # The score that wins the game: the lowest where the game ranks ascending
    # (Golf), the highest otherwise. This is the 1st place the scoring engine
    # pays the pot to, so standings and points agree on who won.
    def best_score(game_type, scores)
      find(game_type).fetch(:ranking) == :asc ? scores.min : scores.max
    end
  end
end
