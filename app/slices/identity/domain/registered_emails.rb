# Read model listing every registered user's email (in registration order),
# for the super admin's handoff recipient suggestions. Callers must only
# expose it to the current super admin (docs/DOMAIN.md § Super admin).
module Identity
  module RegisteredEmails
    extend self

    # Emails of all registered users except the given user's.
    def except(user_id)
      EventStore.project(projection).reject { |id, _| id == user_id }.map { |_, email| email }
    end

    def projection
      DcbEventStore::Projection.new(
        initial_state: [],
        handlers: {
          "UserRegistered" => ->(state, event) { state + [ [ event.data.fetch(:user_id), event.data.fetch(:email) ] ] }
        },
        query: DcbEventStore::Query.new(DcbEventStore::QueryItem.new(event_types: "UserRegistered"))
      )
    end
  end
end
