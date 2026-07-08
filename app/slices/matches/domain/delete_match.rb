# Deletes a registered match, mirroring EditMatch: the decision model reads
# the match and its league in one go, only a player who took part may delete
# it, and only while the league is open. A deleted match folds to gone, so a
# second delete (or a later edit) is rejected with "the match was not found".
# The append condition covers both reads, so a concurrent league close or a
# racing delete wins and this deletion is told to retry.
module Matches
  class DeleteMatch
    def self.call(match_id:, league_id:, account_id:, user_id:)
      decision = decision_for(match_id:, league_id:, account_id:)
      failure = rejection(decision.states, league_id:, account_id:, user_id:)
      return failure if failure

      append_deletion(decision, match_id:, league_id:, account_id:, user_id:)
    rescue DcbEventStore::ConditionNotMet
      Result.failure("the league changed while you were working - please retry")
    end

    def self.decision_for(match_id:, league_id:, account_id:)
      EventStore.decide(
        match: MatchDetails.projection(match_id:),
        league: League.projection(league_id:, account_id:)
      )
    end
    private_class_method :decision_for

    def self.rejection(states, league_id:, account_id:, user_id:)
      match = states.fetch(:match)
      return Result.failure("the match was not found") unless match && match.league_id == league_id && match.account_id == account_id
      return Result.failure("only players in the match can delete it") unless match.players.include?(user_id)
      return Result.failure("the league was not found") if states.fetch(:league).nil?

      Result.failure("the league is closed") if states.fetch(:league).closed?
    end
    private_class_method :rejection

    def self.append_deletion(decision, match_id:, league_id:, account_id:, user_id:)
      event = Events.match_deleted(match_id:, league_id:, account_id:, deleted_by_user_id: user_id)
      EventStore.append(event, decision.append_condition)
      Result.success(match_id)
    end
    private_class_method :append_deletion
  end
end
