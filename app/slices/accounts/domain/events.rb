# The accounts slice's event constructors. Only this module builds the
# events the slice owns, and only this slice appends them (docs/DOMAIN.md).
module Accounts
  module Events
    extend self

    def account_created(account_id:, name:, owner_user_id:)
      DcbEventStore::Event.new(
        type: "AccountCreated",
        data: { account_id:, name:, owner_user_id: },
        tags: [ "account:#{account_id}", "user:#{owner_user_id}" ]
      )
    end

    def player_invited(invitation_id:, account_id:, email:, invited_by_user_id:)
      email = email.strip.downcase
      DcbEventStore::Event.new(
        type: "PlayerInvited",
        data: { invitation_id:, account_id:, email:, invited_by_user_id: },
        tags: [ "invitation:#{invitation_id}", "account:#{account_id}", "invitee_email:#{email}" ]
      )
    end

    def invitation_accepted(invitation_id:, account_id:, user_id:)
      DcbEventStore::Event.new(
        type: "InvitationAccepted",
        data: { invitation_id:, account_id:, user_id: },
        tags: [ "invitation:#{invitation_id}", "account:#{account_id}", "user:#{user_id}" ]
      )
    end

    def invitation_revoked(invitation_id:, account_id:, revoked_by_user_id:)
      DcbEventStore::Event.new(
        type: "InvitationRevoked",
        data: { invitation_id:, account_id:, revoked_by_user_id: },
        tags: [ "invitation:#{invitation_id}", "account:#{account_id}" ]
      )
    end

    def invitation_declined(invitation_id:, account_id:, user_id:)
      DcbEventStore::Event.new(
        type: "InvitationDeclined",
        data: { invitation_id:, account_id:, user_id: },
        tags: [ "invitation:#{invitation_id}", "account:#{account_id}" ]
      )
    end

    def member_left(account_id:, user_id:)
      DcbEventStore::Event.new(
        type: "MemberLeft",
        data: { account_id:, user_id: },
        tags: [ "account:#{account_id}", "user:#{user_id}" ]
      )
    end
  end
end
