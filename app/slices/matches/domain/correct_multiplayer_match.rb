# Corrects a registered multiplayer match's scores. Only a player who took
# part may edit it, and only while the league is open. Score validation: all
# scores must be integers.
module Matches
  class CorrectMultiplayerMatch
    def self.call(match_id:, league_id:, account_id:, user_id:, player_scores:)
      failure = MultiplayerMatchScore.rejection(player_scores)
      return failure if failure

      decision = MatchDecision.read(match_id:, league_id:, account_id:)
      failure = MatchDecision.rejection(decision.states, league_id:, account_id:, user_id:, action: "correct")
      return failure if failure

      append_correction(decision, match_id:, league_id:, account_id:, player_scores:, user_id:)
    rescue DcbEventStore::ConditionNotMet
      Result.failure("the league changed while you were working — please retry")
    end

    def self.append_correction(decision, match_id:, league_id:, account_id:, player_scores:, user_id:)
      event = Events.multiplayer_match_result_corrected(
        match_id:, league_id:, account_id:,
        player_scores: player_scores.transform_values { |v| v.to_i },
        corrected_by_user_id: user_id
      )
      EventStore.append(event, decision.append_condition)
      Result.success(match_id)
    end
    private_class_method :append_correction
  end
end
