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
      active_match = resolve_match(states)
      active_multi = resolve_multiplayer_match(states)

      target = active_match || active_multi
      return Result.failure("the match was not found") unless target

      return Result.failure("only players in the match can #{action} it") unless target_player_ids(target).include?(user_id)
      return Result.failure("the match was not found") unless target.league_id == league_id && target.account_id == account_id

      return Result.failure("the league was not found") unless states.fetch(:league)
      Result.failure("the league is closed") if states.fetch(:league).closed?
    end

    def target_player_ids(target)
      target.respond_to?(:players) ? target.players : target.player_ids
    end
    private_class_method :target_player_ids

    def resolve_match(states)
      match = states.fetch(:match)
      match && !match.deleted? ? match : nil
    end
    private_class_method :resolve_match

    def resolve_multiplayer_match(states)
      multi_match = states.fetch(:multiplayer_match, nil)
      multi_match && !multi_match.deleted? ? multi_match : nil
    end
    private_class_method :resolve_multiplayer_match
  end
end
