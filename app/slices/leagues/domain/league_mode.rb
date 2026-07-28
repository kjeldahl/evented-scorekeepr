# The two modes a league can be run in (docs/DOMAIN.md § Multiplayer matches):
# a match league is the traditional 1v1 / 2v2 head-to-head, a multiplayer
# league ranks every participant's own score.
#
# The mode is chosen on the new-league form and is independent of the game
# type — any game type can be run in either mode. Anything but an explicit
# multiplayer choice (nothing chosen, a blank field, an unknown value) is a
# match league, which is also what leagues created before the mode existed are.
module Leagues
  module LeagueMode
    MATCH = "match".freeze
    MULTIPLAYER = "multiplayer".freeze

    # [human label, code value] pairs for form select helpers; match first so
    # the form's first (preselected) option creates a match league.
    MODES = [ [ "Match", MATCH ], [ "Multiplayer", MULTIPLAYER ] ].freeze

    def self.chosen(mode) = mode.to_s.strip == MULTIPLAYER ? MULTIPLAYER : MATCH
  end
end
