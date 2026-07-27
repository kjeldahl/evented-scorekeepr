# A registered multiplayer match as the scoreboards slice sees it: a flat
# list of players with their individual scores. No shared base with Match —
# consumers pattern-match on the class (docs/DOMAIN.md).
module Scoreboards
  MultiplayerMatch = Data.define(:match_id, :player_ids, :player_scores) do
    def players = player_ids
  end
end