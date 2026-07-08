# The shared decision model for the match commands that act on an existing
# match (EditMatch, DeleteMatch): both read the match and its league in one go,
# only a player who took part may act, and only while the league is open. The
# append condition on the returned decision covers both reads, so a concurrent
# league close or racing change wins and the command is told to retry. The
# rejected-action verb is the caller's ("edit"/"delete") so the messages match
# the feature files verbatim.
module Matches
  module MatchDecision
    extend self

    def read(match_id:, league_id:, account_id:)
      EventStore.decide(
        match: MatchDetails.projection(match_id:),
        league: League.projection(league_id:, account_id:)
      )
    end

    def rejection(states, league_id:, account_id:, user_id:, action:)
      match = states.fetch(:match)
      return Result.failure("the match was not found") unless match && !match.deleted? && match.league_id == league_id && match.account_id == account_id
      return Result.failure("only players in the match can #{action} it") unless match.players.include?(user_id)
      return Result.failure("the league was not found") if states.fetch(:league).nil?

      Result.failure("the league is closed") if states.fetch(:league).closed?
    end
  end
end
