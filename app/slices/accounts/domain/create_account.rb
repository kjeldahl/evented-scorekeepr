# Creates an account (a tenant). The creating user becomes its owner and is
# a member from creation by virtue of the AccountCreated event itself — the
# membership fold treats AccountCreated tagged account+user as membership.
# No invariant depends on prior events, so the append needs no condition.
module Accounts
  class CreateAccount
    def self.call(name:, owner_user_id:)
      name = name.to_s.strip
      return Result.failure("name is required") if name.empty?

      account_id = SecureRandom.uuid
      EventStore.append([ Events.account_created(account_id:, name:, owner_user_id:) ])
      Result.success(account_id)
    end
  end
end
