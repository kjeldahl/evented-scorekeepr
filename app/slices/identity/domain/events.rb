# The identity slice's event constructors. Only this module builds the
# events the slice owns, and only this slice appends them (docs/DOMAIN.md).
module Identity
  module Events
    extend self

    def user_registered(user_id:, name:, email:, password_digest:)
      email = email.strip.downcase
      DcbEventStore::Event.new(
        type: "UserRegistered",
        data: { user_id:, name:, email:, password_digest: },
        tags: [ "user:#{user_id}", "user_email:#{email}" ]
      )
    end

    def user_handle_set(user_id:, handle:)
      DcbEventStore::Event.new(
        type: "UserHandleSet",
        data: { user_id:, handle: },
        tags: [ "user:#{user_id}" ]
      )
    end

    def super_admin_granted(user_id:)
      DcbEventStore::Event.new(
        type: "SuperAdminGranted",
        data: { user_id: },
        tags: [ "user:#{user_id}" ]
      )
    end

    def super_admin_handed_off(from_user_id:, to_user_id:)
      DcbEventStore::Event.new(
        type: "SuperAdminHandedOff",
        data: { from_user_id:, to_user_id: },
        tags: [ "user:#{from_user_id}", "user:#{to_user_id}" ]
      )
    end
  end
end
