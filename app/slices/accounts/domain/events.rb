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

    # Starting a super admin's impersonation session (docs/DOMAIN.md
    # § Impersonation). Tagged with the impersonation, the super admin behind
    # it (user:), the impersonated member (impersonated_user:) and the account
    # the session was started from.
    def impersonation_started(impersonation_id:, super_admin_user_id:, impersonated_user_id:, account_id:)
      DcbEventStore::Event.new(
        type: "ImpersonationStarted",
        data: { impersonation_id:, super_admin_user_id:, impersonated_user_id:, account_id: },
        tags: [ "impersonation:#{impersonation_id}", "user:#{super_admin_user_id}",
                "impersonated_user:#{impersonated_user_id}", "account:#{account_id}" ]
      )
    end

    # Ending a session (ImpersonationEnded) is triggered from two slices (the
    # accounts escape button and identity sign-out), so it is owned by root
    # infrastructure — ImpersonationSession — not this slice.
  end
end
