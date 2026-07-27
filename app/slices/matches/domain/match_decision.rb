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
        multiplayer_match: MultiplayerMatchDetails.projection(match_id:),
        league: League.projection(league_id:, account_id:)
      )
    end

    def rejection(states, league_id:, account_id:, user_id:, action:)
      match = states.fetch(:match)
      multi_match = states.fetch(:multiplayer_match, nil)
      active_match = match && !match.deleted? ? match : nil
      active_multi = multi_match && !multi_match.deleted? ? multi_match : nil

      return Result.failure("the match was not found") unless active_match || active_multi
      if active_match
        return Result.failure("only players in the match can #{action} it") unless active_match.players.include?(user_id)
        return Result.failure("the match was not found") unless active_match.league_id == league_id && active_match.account_id == account_id
      else
        return Result.failure("only players in the match can #{action} it") unless active_multi.player_ids.include?(user_id)
        return Result.failure("the match was not found") unless active_multi.league_id == league_id && active_multi.account_id == account_id
      end
      return Result.failure("the league was not found") if states.fetch(:league).nil?

      Result.failure("the league is closed") if states.fetch(:league).closed?
    end
  end
end
