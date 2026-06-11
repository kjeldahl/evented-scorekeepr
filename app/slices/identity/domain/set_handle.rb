# Sets the signed-in user's display handle, shown instead of the registered
# name wherever players are displayed (docs/DOMAIN.md). The latest handle
# wins and there is no uniqueness constraint, so nothing is read and the
# append carries no condition (like Accounts::CreateAccount).
module Identity
  class SetHandle
    def self.call(user_id:, handle:)
      handle = handle.to_s.strip
      return Result.failure("handle is required") if handle.empty?

      EventStore.append(Events.user_handle_set(user_id:, handle:))
      Result.success(user_id)
    end
  end
end
