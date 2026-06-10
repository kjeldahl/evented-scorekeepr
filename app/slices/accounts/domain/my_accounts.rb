# Read model for the dashboard: the accounts a user belongs to, i.e. every
# account they created (AccountCreated) or were accepted into
# (InvitationAccepted), folded by the user:{id} tag.
module Accounts
  module MyAccounts
    extend self

    def for_user(user_id)
      EventStore.project(account_ids_projection(user_id)).filter_map { |account_id| Account.find(account_id) }
    end

    def account_ids_projection(user_id)
      DcbEventStore::Projection.new(
        initial_state: [],
        handlers: {
          "AccountCreated" => ->(state, event) { state | [ event.data.fetch(:account_id) ] },
          "InvitationAccepted" => ->(state, event) { state | [ event.data.fetch(:account_id) ] }
        },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(
            event_types: %w[AccountCreated InvitationAccepted],
            tags: "user:#{user_id}"
          )
        )
      )
    end
  end
end
