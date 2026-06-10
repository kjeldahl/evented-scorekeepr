require "bcrypt"

# Registers a new user. Email uniqueness is enforced with a DCB decision
# model over the `user_email:{email}` tag plus its append condition, so two
# concurrent registrations of the same email cannot both succeed.
module Identity
  class RegisterUser
    def self.call(name:, email:, password:)
      name = name.to_s.strip
      email = email.to_s.strip.downcase
      password = password.to_s
      return Result.failure("name is required") if name.empty?
      return Result.failure("email is required") if email.empty?
      return Result.failure("password is required") if password.empty?

      register(name:, email:, password:)
    end

    def self.register(name:, email:, password:)
      decision = EventStore.decide(registered: EmailRegistration.projection(email))
      return Result.failure("email is already registered") if decision.states.fetch(:registered)

      user_id = SecureRandom.uuid
      EventStore.append(registration_event(user_id, name, email, password), decision.append_condition)
      Result.success(user_id)
    rescue DcbEventStore::ConditionNotMet
      Result.failure("email is already registered")
    end
    private_class_method :register

    def self.registration_event(user_id, name, email, password)
      # BCrypt::Password is a String subclass; the store serialises it as the digest string.
      Events.user_registered(user_id:, name:, email:, password_digest: BCrypt::Password.create(password))
    end
    private_class_method :registration_event
  end
end
