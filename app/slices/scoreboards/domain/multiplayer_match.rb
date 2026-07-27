# A registered multiplayer match as the scoreboards slice sees it: a flat
# list of players with their individual scores. No shared base with Match —
# consumers pattern-match on the class (docs/DOMAIN.md).
# A deleted match stays in the list (so the `seed` step still reaches all
# participants at their starting points) but is ignored by the scoring
# engine.
module Scoreboards
  MultiplayerMatch = Data.define(:match_id, :player_ids, :player_scores, :deleted) do
    def players = player_ids
    def deleted? = deleted
  end
end
