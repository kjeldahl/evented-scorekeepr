require "bcrypt"

# Verifies email + password against the stored credentials. Unknown email
# and wrong password fail identically so sign-in does not reveal whether an
# email is registered.
module Identity
  class AuthenticateUser
    INVALID_CREDENTIALS = "invalid credentials"

    def self.call(email:, password:)
      credentials = Credentials.find_by_email(email.to_s.strip.downcase)
      return Result.failure(INVALID_CREDENTIALS) unless credentials
      return Result.failure(INVALID_CREDENTIALS) unless password_matches?(credentials, password)

      Result.success(credentials[:user_id])
    end

    def self.password_matches?(credentials, password)
      BCrypt::Password.new(credentials[:password_digest]) == password.to_s
    end
    private_class_method :password_matches?
  end
end
