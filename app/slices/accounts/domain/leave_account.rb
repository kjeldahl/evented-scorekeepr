# Lets a member — the owner included — leave an account. Membership ends
# with a MemberLeft event; history (registered matches, standings) is
# untouched and the departed member can be invited back in. The membership
# decision model's append condition makes leaving race-free.
module Accounts
  class LeaveAccount
    def self.call(account_id:, user_id:)
      decision = EventStore.decide(member: Membership.projection(account_id:, user_id:))
      return Result.failure("only members can leave an account") unless decision.states.fetch(:member)

      EventStore.append(Events.member_left(account_id:, user_id:), decision.append_condition)
      Result.success(account_id)
    rescue DcbEventStore::ConditionNotMet
      Result.failure("the account changed while you were working — please retry")
    end
  end
end
