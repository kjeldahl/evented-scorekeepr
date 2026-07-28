# A registered multiplayer match as the scoreboards slice sees it: a flat
# list of players with their individual scores. No shared base with Match —
# consumers pattern-match on the class (docs/DOMAIN.md).
# A deleted match is dropped from the fold entirely, so nothing here carries
# a deleted flag: the league re-derives as if the match had never been
# registered, and a player who only appeared in it leaves the standings.
module Scoreboards
  MultiplayerMatch = Data.define(:match_id, :player_ids, :player_scores) do
    def players = player_ids
  end
end
