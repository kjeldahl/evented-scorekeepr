# A registered match as the statistics slice sees it: the sides, the game
# score and who won (draws are never stored, so the score always decides).
# Winners keep the order they were listed on the match — the pot remainder
# is handed out in that order (docs/DOMAIN.md).
module Statistics
  Match = Data.define(:match_id, :home_player_ids, :away_player_ids, :home_score, :away_score) do
    def players = home_player_ids + away_player_ids
    def winners = home_win? ? home_player_ids : away_player_ids
    def losers = home_win? ? away_player_ids : home_player_ids
    def winner_score = home_win? ? home_score : away_score
    def loser_score = home_win? ? away_score : home_score
    def home_win? = home_score > away_score
    def involves?(player_id) = players.include?(player_id)
    def won_by?(player_id) = winners.include?(player_id)
    def opponents_of(player_id) = home_player_ids.include?(player_id) ? away_player_ids : home_player_ids
  end
end
