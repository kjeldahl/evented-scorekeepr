# Corrects a registered match's score. Input shape first: scores are
# non-negative integers and no draws - the same rules a freshly registered
# match obeys (docs/DOMAIN.md). Then the decision model reads the match and
# its league in one go: only a player who took part may edit it, and only
# while the league is open. The append condition covers both reads, so a
# concurrent league close wins and the correction is told to retry.
module Matches
  class EditMatch
    def self.call(match_id:, league_id:, account_id:, user_id:, home_score:, away_score:)
      home_score = MatchScore.parse(home_score)
      away_score = MatchScore.parse(away_score)
      failure = MatchScore.rejection(home_score, away_score)
      return failure if failure

      decision = MatchDecision.read(match_id:, league_id:, account_id:)
      failure = MatchDecision.rejection(decision.states, league_id:, account_id:, user_id:, action: "edit")
      return failure if failure

      append_correction(decision, match_id:, league_id:, account_id:, home_score:, away_score:, user_id:)
    rescue DcbEventStore::ConditionNotMet
      Result.failure("the league changed while you were working — please retry")
    end

    def self.append_correction(decision, match_id:, league_id:, account_id:, home_score:, away_score:, user_id:)
      event = Events.match_result_corrected(
        match_id:, league_id:, account_id:, home_score:, away_score:, corrected_by_user_id: user_id
      )
      EventStore.append(event, decision.append_condition)
      Result.success(match_id)
    end
    private_class_method :append_correction
  end
end
