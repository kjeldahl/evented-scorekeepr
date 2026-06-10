# Read model for the account page's members list: the owner plus everyone
# who accepted an invitation, with display names resolved by folding the
# identity slice's UserRegistered events (events are the cross-slice
# contract — docs/ARCHITECTURE.md).
module Accounts
  module Members
    Member = Data.define(:user_id, :name)

    module_function

    def for_account(account_id)
      EventStore.project(member_ids_projection(account_id)).map do |user_id|
        Member.new(user_id:, name: user_name(user_id))
      end
    end

    def member_ids_projection(account_id)
      DcbEventStore::Projection.new(
        initial_state: [],
        handlers: {
          "AccountCreated" => ->(state, event) { state | [ event.data[:owner_user_id] ] },
          "InvitationAccepted" => ->(state, event) { state | [ event.data[:user_id] ] }
        },
        query: DcbEventStore::Query.new([
          DcbEventStore::QueryItem.new(
            event_types: %w[AccountCreated InvitationAccepted],
            tags: [ "account:#{account_id}" ]
          )
        ])
      )
    end

    def user_name(user_id)
      EventStore.project(user_name_projection(user_id))
    end

    def user_name_projection(user_id)
      DcbEventStore::Projection.new(
        initial_state: nil,
        handlers: { "UserRegistered" => ->(_state, event) { event.data[:name] } },
        query: DcbEventStore::Query.new([
          DcbEventStore::QueryItem.new(event_types: %w[UserRegistered], tags: [ "user:#{user_id}" ])
        ])
      )
    end
  end
end
