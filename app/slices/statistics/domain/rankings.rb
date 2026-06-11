# League ranking for the player page: players ordered by points descending,
# ties ordered alphabetically by display name with sequential ranks
# (docs/DOMAIN.md). Unknown names fall back to the player id.
module Statistics
  module Rankings
    extend self

    # points: { player_id => points } for every ranked player.
    # => the player's 1-based rank, or nil when they are not ranked.
    def rank_of(player_id, points:, names:)
      position = order(points:, names:).index(player_id)
      position && position + 1
    end

    def order(points:, names:)
      points.keys.sort_by { |player| [ -points.fetch(player), names.fetch(player, player) ] }
    end
  end
end
