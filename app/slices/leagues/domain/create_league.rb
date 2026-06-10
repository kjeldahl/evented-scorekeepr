# Creates a league in an account. Only members can create leagues (the
# membership decision model's append condition guards the invariant against
# concurrent appends). An account can host many leagues at once, also for
# the same game type, so there is no uniqueness constraint. Settings default
# to 1000 starting points and a 10% stake; blank values fall back to the
# defaults, while present values must be a positive integer (points) and an
# integer between 1 and 99 (stake).
module Leagues
  class CreateLeague
    DEFAULT_STARTING_POINTS = 1000
    DEFAULT_STAKE_PERCENTAGE = 10

    def self.call(account_id:, user_id:, name:, game_type:,
                  starting_points: DEFAULT_STARTING_POINTS, stake_percentage: DEFAULT_STAKE_PERCENTAGE)
      name = name.to_s.strip
      starting_points = coerce(starting_points, DEFAULT_STARTING_POINTS)
      stake_percentage = coerce(stake_percentage, DEFAULT_STAKE_PERCENTAGE)
      failure = invalid_settings(name, starting_points, stake_percentage)
      return failure if failure

      decision = EventStore.decide(member: Membership.projection(account_id:, user_id:))
      return Result.failure("only members can create leagues") unless decision.states[:member]

      append_league(decision, account_id:, name:, game_type: game_type.to_s.strip,
                              starting_points:, stake_percentage:)
    rescue DcbEventStore::ConditionNotMet
      Result.failure("the account changed while you were working — please retry")
    end

    def self.coerce(value, default)
      return default if value.nil? || value.to_s.strip.empty?

      Integer(value.to_s, exception: false)
    end
    private_class_method :coerce

    def self.invalid_settings(name, starting_points, stake_percentage)
      return Result.failure("name is required") if name.empty?
      return Result.failure("starting points must be positive") unless starting_points&.positive?

      Result.failure("stake must be between 1 and 99") unless (1..99).cover?(stake_percentage)
    end
    private_class_method :invalid_settings

    def self.append_league(decision, account_id:, name:, game_type:, starting_points:, stake_percentage:)
      league_id = SecureRandom.uuid
      event = Events.league_created(league_id:, account_id:, name:, game_type:,
                                    starting_points:, stake_percentage:)
      EventStore.append([ event ], decision.append_condition)
      Result.success(league_id)
    end
    private_class_method :append_league
  end
end
