# The statistics slice's own membership fold: a user is a member of an
# account iff the latest membership event for the account + user pair grants
# it — AccountCreated (the owner) and InvitationAccepted grant membership,
# MemberLeft ends it (a later accepted invitation grants it again). The accounts slice owns these events; this slice folds them itself
# because events are the only cross-slice contract (docs/ARCHITECTURE.md).
module Statistics
  module Membership
    extend self

    def member?(account_id:, user_id:)
      EventStore.project(projection(account_id:, user_id:))
    end

    def projection(account_id:, user_id:)
      DcbEventStore::Projection.new(
        initial_state: false,
        handlers: {
          "AccountCreated" => ->(_state, _event) { true },
          "InvitationAccepted" => ->(_state, _event) { true },
          "MemberLeft" => ->(_state, _event) { false }
        },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(
            event_types: %w[AccountCreated InvitationAccepted MemberLeft],
            tags: [ "account:#{account_id}", "user:#{user_id}" ]
          )
        )
      )
    end
  end
end
