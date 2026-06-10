# Decision-model projection answering "is this email already registered?".
# Folded over UserRegistered events tagged with the normalised email, so the
# append condition built from its query makes registration race-free.
module Identity
  module EmailRegistration
    extend self

    def projection(email)
      DcbEventStore::Projection.new(
        initial_state: false,
        handlers: { "UserRegistered" => ->(_state, _event) { true } },
        query: DcbEventStore::Query.new(
          DcbEventStore::QueryItem.new(event_types: "UserRegistered", tags: "user_email:#{email}")
        )
      )
    end
  end
end
