# Internal proportional ratios (0..10000 basis-points) per player count for
# the multiplayer stake model (docs/DOMAIN.md). Position 1 (index 0) is 0
# (the winner); every other position pays basis_points/10000 ×
# stake_percentage × current_points.
#
# Stored as integers so that **all arithmetic is integer only** — no floats,
# no rounding drift, no loss or creation of points. Each row sums to 10000.
module Matches
  module Distribution
    BASIS_POINT = {
      2 => [     0, 10000 ],
      3 => [      0,  3750, 6250 ],
      4 => [      0,  2500, 4000, 3500 ],
      5 => [      0,  1800, 2700, 3300, 2200 ],
      6 => [      0,  1500, 2300, 2800, 2200, 1200 ],
      7 => [      0,  1300, 1900, 2300, 2000, 1500, 1000 ],
      8 => [      0,  1100, 1700, 2100, 1900, 1600, 1200,  400 ]
    }.freeze

    extend self

    def basis_point_for(player_count, position)
      BASIS_POINT.fetch(player_count, []).fetch(position, 0)
    end

    # Legacy accessor for the float-based tests (mirrors the old API).
    def ratio_for(player_count, position)
      basis_point_for(player_count, position) / 10_000.0
    end
  end
end
