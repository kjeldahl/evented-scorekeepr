# Registers a multiplayer match result in a league. Each player enters one
# integer score; players are ranked by score (per game type) and points are
# distributed via the MultiplayerScoringEngine. Input shape first: player_ids
# is non-empty, within game type's min/max, all distinct; scores are integers
# (can be negative). Then the decision model checks the registrar's membership,
# the league's lifecycle, and every player's membership.
module Matches
  class RegisterMultiplayerMatch
    def self.call(league_id:, account_id:, user_id:, player_ids:, player_scores:)
      # Deduplicate: last score wins if a player appears twice (but we still
      # detect and reject in validation below).
      player_ids = Array(player_ids).map(&:to_s).map(&:strip).reject(&:empty?)

      failure = invalid_input(player_ids, player_scores)
      return failure if failure

      decision = decision_for(league_id:, account_id:, user_id:, player_ids:)
      failure = rejection(decision.states, player_ids)
      return failure if failure

      append_match(decision, league_id:, account_id:, player_ids:, player_scores:, user_id:)
    rescue DcbEventStore::ConditionNotMet
      Result.failure("the league changed while you were working — please retry")
    end

    def self.invalid_input(player_ids, player_scores)
      return Result.failure("at least 1 participant is required") if player_ids.empty?
      return Result.failure("players must be distinct") unless player_ids.uniq.size == player_ids.size

      score_rejection = MultiplayerMatchScore.rejection(player_scores)
      return score_rejection if score_rejection
      nil
    end
    private_class_method :invalid_input

    def self.decision_for(league_id:, account_id:, user_id:, player_ids:)
      EventStore.decide(
        member: Membership.projection(account_id:, user_id:),
        league: League.projection(league_id:, account_id:),
        players: PlayerMembership.projection(account_id:, player_ids:)
      )
    end
    private_class_method :decision_for

    def self.rejection(states, player_ids)
      return Result.failure("only members can register matches") unless states.fetch(:member)
      return Result.failure("the league was not found") if states.fetch(:league).nil?
      return Result.failure("the league is closed") if states.fetch(:league).closed?

      Result.failure("all players must be members of the account") unless (player_ids - states.fetch(:players)).empty?
    end
    private_class_method :rejection

    def self.append_match(decision, league_id:, account_id:, player_ids:, player_scores:, user_id:)
      match_id = SecureRandom.uuid
      event = Events.multiplayer_match_registered(
        match_id:, league_id:, account_id:, player_ids:,
        player_scores: MultiplayerMatchScore.parse_all(player_scores),
        registered_by_user_id: user_id
      )
      EventStore.append(event, decision.append_condition)
      Result.success(match_id)
    end
    private_class_method :append_match
  end
end
