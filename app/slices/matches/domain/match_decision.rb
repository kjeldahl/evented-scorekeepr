# The shared decision model for the match commands that act on an existing
# match (EditMatch, CorrectMultiplayerMatch, DeleteMatch): a match id names a
# head-to-head match or a multiplayer one, so the model reads both kinds and
# the league in one go. Only a player who took part may act, and only while the
# league is open. The
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

    # `multiplayer` names the kind of match the caller acts on (true, false, or
    # nil for either kind): a live match of the other kind is not a match this
    # command can act on, so it reads as "not found".
    def rejection(states, league_id:, account_id:, user_id:, action:, multiplayer: nil)
      match = actionable_match(states, multiplayer)
      return Result.failure("the match was not found") unless match

      return Result.failure("only players in the match can #{action} it") unless match.players.include?(user_id)
      return Result.failure("the match was not found") unless match.league_id == league_id && match.account_id == account_id

      return Result.failure("the league was not found") unless states.fetch(:league)
      Result.failure("the league is closed") if states.fetch(:league).closed?
    end

    # The live match the id names, of either kind, or nil. Commands whose
    # appended event depends on the kind ask this after `rejection` passed.
    def active_match(states)
      resolve_match(states) || resolve_multiplayer_match(states)
    end

    def actionable_match(states, multiplayer)
      match = active_match(states)
      match if match && (multiplayer.nil? || match.multiplayer? == multiplayer)
    end
    private_class_method :actionable_match

    # A deleted match reads as gone, so the fold's `deleted?` flag maps back to
    # "no live match here" - the same boundary `find` applies to reads.
    def resolve_match(states)
      match = states.fetch(:match)
      match unless match&.deleted?
    end
    private_class_method :resolve_match

    def resolve_multiplayer_match(states)
      multi_match = states.fetch(:multiplayer_match)
      multi_match unless multi_match&.deleted?
    end
    private_class_method :resolve_multiplayer_match
  end
end
