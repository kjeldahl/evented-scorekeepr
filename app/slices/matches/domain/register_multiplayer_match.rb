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

      league = league_for(league_id:, account_id:)
      failure = invalid_input(player_ids, player_scores, league:)
      return failure if failure

      decision = decision_for(league_id:, account_id:, user_id:, player_ids:, league:)
      failure = rejection(decision.states, player_ids)
      return failure if failure

      append_match(decision, league_id:, account_id:, player_ids:, player_scores:, user_id:)
    rescue DcbEventStore::ConditionNotMet
      Result.failure("the league changed while you were working — please retry")
    end

    # Input shape validation: half-filled rows, distinct players, game type
    # min/max count, then score format.  Rejection order is fixed so each
    # mistake reports its own cause (DOMAIN.md).
    def self.invalid_input(player_ids, player_scores, league:)
      half = half_filled_rejection(player_ids, player_scores)
      return half if half

      return Result.failure("players must be distinct") unless player_ids.uniq.size == player_ids.size

      count_rejection = player_count_rejection(player_ids.size, league)
      return count_rejection if count_rejection

      return Result.failure("at least 1 participant is required") if player_ids.empty?

      score_rejection = MultiplayerMatchScore.rejection(player_scores)
      return score_rejection if score_rejection
      nil
    end
    private_class_method :invalid_input

    # A half-filled row: player present without score, or score without player.
    # Checks every submitted id-key / score-value pair against each other.
    # Player ids arrive in `player_ids` (array of user ids); scores arrive as
    # a hash keyed by user id (the form sends a blank key "" for rows where
    # the score was entered but no player was selected).
    def self.half_filled_rejection(player_ids, player_scores)
      # Scores keyed by an id that has no matching player id: either a blank
      # key (the form's empty-string sentinel) or a real uid for a row that
      # was left with no player selected.
      if player_scores.key?("") || (player_scores.keys - player_ids).any?
        return Result.failure("every score needs a player")
      end

      # Player ids with no matching score.
      player_ids.each do |id|
        next if id.strip.empty?
        return Result.failure("every player needs a score") unless player_scores.key?(id) && !player_scores[id].to_s.empty?
      end

      nil
    end
    private_class_method :half_filled_rejection

    # Game type fixes the allowed player count range.
    def self.player_count_rejection(count, league)
      return nil unless league && league.multiplayer_league?
      return nil if GameType.valid_player_count?(league.game_type, count)

      config = GameType.find(league.game_type)
      Result.failure("a #{league.game_type} match needs #{config[:min_players]} to #{config[:max_players]} players")
    end
    private_class_method :player_count_rejection

    def self.league_for(league_id:, account_id:)
      League.find(league_id:, account_id:)
    end
    private_class_method :league_for

    def self.decision_for(league_id:, account_id:, user_id:, player_ids:, league:)
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
