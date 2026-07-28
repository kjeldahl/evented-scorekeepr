# Frozen code constant listing the known game types.
# Mirrors the keys in the scoreboards slice's game type config so the selector
# only offers types that the scoring engine knows how to handle.
# (docs/ARCHITECTURE.md rule #3: the leagues slice does not import scoreboards;
# it keeps its own read-only copy of the type list. The actual config lives in
# Scoreboards::MultiplayerGameType.)
module Leagues
  module GameType
    # [human label, code value] pairs for form select helpers.
    TYPES = [
      ["Foosball", "Foosball"],
      ["Table Tennis", "Table Tennis"],
      ["Pool", "Pool"],
      ["Darts", "Darts"],
      ["Golf", "Golf"],
      ["Norsk Rummy", "Norsk Rummy"]
    ].freeze
  end
end