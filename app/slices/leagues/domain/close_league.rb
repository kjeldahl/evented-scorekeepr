# Closes an open league. Only members can close leagues, and a league can
# be closed only once — the league decision model's narrow league+account
# query builds an append condition that makes two concurrent closes
# impossible: the loser of the race is told the league is already closed.
module Leagues
  class CloseLeague
    def self.call(league_id:, account_id:, user_id:)
      decision = EventStore.decide(
        league: LeagueState.projection(league_id:, account_id:),
        member: Membership.projection(account_id:, user_id:)
      )
      failure = rejection(decision.states)
      return failure if failure

      EventStore.append([ Events.league_closed(league_id:, account_id:) ], decision.append_condition)
      Result.success(league_id)
    rescue DcbEventStore::ConditionNotMet
      Result.failure("the league is closed")
    end

    def self.rejection(states)
      return Result.failure("only members can close leagues") unless states[:member]
      return Result.failure("the league was not found") if states[:league] == :none

      Result.failure("the league is closed") if states[:league] == :closed
    end
    private_class_method :rejection
  end
end
