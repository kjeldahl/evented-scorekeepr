# The score-input rules for multiplayer matches (docs/DOMAIN.md): each score
# is an integer (negative scores allowed for games like Golf where lower is
# better). Blank or non-integer input is rejected.
module Matches
  module MultiplayerMatchScore
    extend self

    def parse(value)
      Integer(value.to_s, exception: false)
    end

    # nil when every score parses as an integer; a Result.failure otherwise.
    def rejection(scores_by_name)
      scores_by_name.each do |name, raw|
        parsed = parse(raw)
        return Result.failure("scores must be integers") if parsed.nil?
      end
      nil
    end

    def valid?(scores_by_name)
      rejection(scores_by_name).nil?
    end
  end
end