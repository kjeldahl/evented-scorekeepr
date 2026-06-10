# Registers a match result in a league. Input shape first: each side has 1
# or 2 players, all players distinct, scores non-negative integers (blank or
# non-integer input is rejected), no draws. Then the decision model checks
# the registrar's membership, the league's lifecycle and every player's
# membership in one read, and its append condition makes the write race-free
# — a concurrent league close wins, and this registration is told to retry.
module Matches
  class RegisterMatch
    def self.call(league_id:, account_id:, user_id:, home_player_ids:, away_player_ids:,
                  home_score:, away_score:)
      home = side(home_player_ids)
      away = side(away_player_ids)
      home_score = score(home_score)
      away_score = score(away_score)
      failure = invalid_input(home, away, home_score, away_score)
      return failure if failure

      decision = decision_for(league_id:, account_id:, user_id:, players: home + away)
      failure = rejection(decision.states, home + away)
      return failure if failure

      append_match(decision, league_id:, account_id:, home:, away:, home_score:, away_score:, user_id:)
    rescue DcbEventStore::ConditionNotMet
      Result.failure("the league changed while you were working — please retry")
    end

    def self.side(player_ids)
      Array(player_ids).map { |id| id.to_s.strip }.reject(&:empty?)
    end
    private_class_method :side

    def self.score(value)
      Integer(value.to_s, exception: false) # Kernel#Integer ignores surrounding whitespace
    end
    private_class_method :score

    def self.invalid_input(home, away, home_score, away_score)
      return Result.failure("each side must have 1 or 2 players") unless valid_sides?(home, away)
      return Result.failure("a player cannot be on both sides") unless distinct_players?(home, away)
      return Result.failure("scores must be non-negative integers") unless valid_scores?(home_score, away_score)

      Result.failure("draws are not allowed") if home_score == away_score
    end
    private_class_method :invalid_input

    def self.valid_sides?(home, away)
      [ home, away ].all? { |players| (1..2).cover?(players.size) }
    end
    private_class_method :valid_sides?

    def self.distinct_players?(home, away)
      (home + away).uniq.size == home.size + away.size
    end
    private_class_method :distinct_players?

    def self.valid_scores?(home_score, away_score)
      [ home_score, away_score ].all? { |score| !score.nil? && score >= 0 }
    end
    private_class_method :valid_scores?

    def self.decision_for(league_id:, account_id:, user_id:, players:)
      EventStore.decide(
        member: Membership.projection(account_id:, user_id:),
        league: League.projection(league_id:, account_id:),
        players: PlayerMembership.projection(account_id:, player_ids: players)
      )
    end
    private_class_method :decision_for

    def self.rejection(states, players)
      return Result.failure("only members can register matches") unless states.fetch(:member)
      return Result.failure("the league was not found") if states.fetch(:league).nil?
      return Result.failure("the league is closed") if states.fetch(:league).closed?

      Result.failure("all players must be members of the account") unless (players - states.fetch(:players)).empty?
    end
    private_class_method :rejection

    def self.append_match(decision, league_id:, account_id:, home:, away:, home_score:, away_score:, user_id:)
      match_id = SecureRandom.uuid
      event = Events.match_registered(
        match_id:, league_id:, account_id:, home_player_ids: home, away_player_ids: away,
        home_score:, away_score:, registered_by_user_id: user_id
      )
      EventStore.append(event, decision.append_condition)
      Result.success(match_id)
    end
    private_class_method :append_match
  end
end
