# Internal proportional ratios (0..1) per player count for the multiplayer
# stake model (docs/DOMAIN.md). Position 1 (index 0) pays 0% (the winner);
# every other position pays its ratio × stake_percentage × current_points.
# Tied players share the average of their shared positions' ratios.
#
# Valid player counts: 2..8. 1-player matches bypass this module entirely
# (no stakes, no gains).
module Matches
  module Distribution
    RATIO = {
      2 => [0.0,  1.0],
      3 => [0.0,  0.375, 0.625],
      4 => [0.0,  0.25,  0.40,  0.35],
      5 => [0.0,  0.18,  0.27,  0.33,  0.22],
      6 => [0.0,  0.15,  0.23,  0.28,  0.22,  0.12],
      7 => [0.0,  0.13,  0.19,  0.23,  0.20,  0.15,  0.10],
      8 => [0.0,  0.11,  0.17,  0.21,  0.19,  0.16,  0.12,  0.04],
    }.freeze

    extend self

    def ratio_for(player_count, position)
      RATIO.fetch(player_count, [])[position] || 0.0
    end
  end
end