# Frozen code constant mapping game_type strings to config: ranking direction,
# min/max players, and an implicit mode (:match or :multiplayer). Unknown game
# types default to desc ranking, 2-4 players (matching the default match league
# constraints). (docs/DOMAIN.md)
module Matches
  module GameType
    DEFAULT = { ranking: :desc, min_players: 2, max_players: 4 }.freeze

    CONFIG = {
      "Foosball"   => { ranking: :desc, min_players: 2, max_players: 4 }.freeze,
      "Table Tennis" => { ranking: :desc, min_players: 2, max_players: 4 }.freeze,
      "Golf"       => { ranking: :asc, min_players: 1, max_players: 8 }.freeze
    }.freeze

    extend self

    def find(game_type)
      CONFIG.fetch(game_type, DEFAULT)
    end

    def valid_player_count?(game_type, count)
      config = find(game_type)
      count = Integer(count) if count.respond_to?(:to_int)
      (config[:min_players]..config[:max_players]).cover?(count)
    end
  end
end
