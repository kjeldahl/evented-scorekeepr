# Frozen code constant mapping game_type strings to config: ranking direction,
# min/max players, and an implicit mode (:match or :multiplayer). Unknown game
# types default to desc ranking, 2-4 players (matching the default match league
# constraints). (docs/DOMAIN.md)
# (This is a copy of Matches::GameType so scoreboards can rank without
# referencing the matches slice — docs/ARCHITECTURE.md rule #3.)
module Scoreboards
  module MultiplayerGameType
    DEFAULT = { ranking: :desc, min_players: 2, max_players: 4 }.freeze

    CONFIG = {
      "Foosball"     => { ranking: :desc, min_players: 2, max_players: 4 }.freeze,
      "Table Tennis" => { ranking: :desc, min_players: 2, max_players: 4 }.freeze,
      "Golf"         => { ranking: :asc, min_players: 1, max_players: 8 }.freeze
    }.freeze

    extend self

    def find(game_type)
      CONFIG.fetch(game_type, DEFAULT)
    end
  end
end
