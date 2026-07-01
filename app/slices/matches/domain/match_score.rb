# The score-input rules every match command shares (docs/DOMAIN.md): each
# score is a non-negative integer - blank or non-integer input is rejected -
# and the two scores never tie, because a draw is never stored. RegisterMatch
# and EditMatch both parse and validate scores through here so the rule (and
# its rejection messages) lives in one place.
module Matches
  module MatchScore
    extend self

    def parse(value)
      Integer(value.to_s, exception: false) # Kernel#Integer ignores surrounding whitespace
    end

    # nil when the pair is a valid, non-drawn score; a Result.failure otherwise.
    def rejection(home_score, away_score)
      return Result.failure("scores must be non-negative integers") unless valid?(home_score, away_score)

      Result.failure("draws are not allowed") if home_score == away_score
    end

    def valid?(home_score, away_score)
      [ home_score, away_score ].all? { |score| !score.nil? && score >= 0 }
    end
    private :valid?
  end
end
