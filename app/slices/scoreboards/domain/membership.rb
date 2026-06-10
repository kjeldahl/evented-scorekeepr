# The scoreboards slice's own membership fold: a user is a member of an
# account iff they own it (AccountCreated tagged with both account and user)
# or they accepted an invitation into it (InvitationAccepted with the same
# tags). The accounts slice owns these events; this slice folds them itself
# because events are the only cross-slice contract (docs/ARCHITECTURE.md).
module Scoreboards
  module Membership
    module_function

    def member?(account_id:, user_id:)
      EventStore.project(projection(account_id:, user_id:))
    end

    def projection(account_id:, user_id:)
      DcbEventStore::Projection.new(
        initial_state: false,
        handlers: {
          "AccountCreated" => ->(_state, _event) { true },
          "InvitationAccepted" => ->(_state, _event) { true }
        },
        query: DcbEventStore::Query.new([
          DcbEventStore::QueryItem.new(
            event_types: %w[AccountCreated InvitationAccepted],
            tags: [ "account:#{account_id}", "user:#{user_id}" ]
          )
        ])
      )
    end
  end
end
