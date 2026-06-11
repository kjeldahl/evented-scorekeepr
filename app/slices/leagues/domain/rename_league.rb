# Renames an open league. Only members can rename, the name must be present
# and closed leagues keep their name; the decision model's append condition
# makes renaming race-free against a concurrent close.
module Leagues
  class RenameLeague
    def self.call(league_id:, account_id:, user_id:, name:)
      name = name.to_s.strip
      return Result.failure("name is required") if name.empty?

      decision = EventStore.decide(
        league: LeagueState.projection(league_id:, account_id:),
        member: Membership.projection(account_id:, user_id:)
      )
      failure = rejection(decision.states)
      return failure if failure

      EventStore.append(Events.league_renamed(league_id:, account_id:, name:), decision.append_condition)
      Result.success(league_id)
    rescue DcbEventStore::ConditionNotMet
      Result.failure("the league is closed")
    end

    def self.rejection(states)
      return Result.failure("only members can rename leagues") unless states.fetch(:member)
      return Result.failure("the league was not found") if states.fetch(:league) == :none

      Result.failure("the league is closed") if states.fetch(:league) == :closed
    end
    private_class_method :rejection
  end
end
