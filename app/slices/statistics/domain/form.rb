# A player's form: their last five results in the league as "W"/"L" tokens,
# most recent first — fewer if they played fewer matches (docs/DOMAIN.md).
module Statistics
  module Form
    LIMIT = 5

    extend self

    # matches: the league's matches oldest first.
    # => e.g. [ "W", "W", "L" ] — newest result first, at most LIMIT tokens.
    def tokens(matches, player_id:)
      matches.select { |match| match.involves?(player_id) }
             .map { |match| match.won_by?(player_id) ? "W" : "L" }
             .reverse
             .first(LIMIT)
    end
  end
end
