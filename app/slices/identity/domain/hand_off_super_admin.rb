# Hands the super admin status from the acting user to the registered user
# with the given email (docs/DOMAIN.md § Super admin). One atomic append of a
# SuperAdminRevoked for the actor and a SuperAdminGranted for the recipient,
# guarded by the decision model (current holder + recipient lookup), so there
# is never more than one super admin and a concurrent change is re-decided.
# Handing off to oneself is a no-op success.
module Identity
  class HandOffSuperAdmin
    NOT_SUPER_ADMIN = "only the super admin can hand off the super admin status".freeze
    NO_SUCH_USER = "there is no user with that email".freeze

    def self.call(actor_user_id:, email:)
      email = email.to_s.strip.downcase
      decision = EventStore.decide(
        super_admin: CurrentSuperAdmin.projection,
        recipient: UserByEmail.projection(email)
      )
      failure = rejection(decision.states, actor_user_id)
      return failure if failure

      recipient_id = decision.states.fetch(:recipient)
      hand_over(decision, actor_user_id, recipient_id) unless recipient_id == actor_user_id
      Result.success(recipient_id)
    rescue DcbEventStore::ConditionNotMet
      call(actor_user_id:, email:)
    end

    def self.rejection(states, actor_user_id)
      return Result.failure(NOT_SUPER_ADMIN) unless states.fetch(:super_admin) == actor_user_id

      Result.failure(NO_SUCH_USER) unless states.fetch(:recipient)
    end
    private_class_method :rejection

    def self.hand_over(decision, actor_user_id, recipient_id)
      EventStore.append(
        [ Events.super_admin_revoked(user_id: actor_user_id), Events.super_admin_granted(user_id: recipient_id) ],
        decision.append_condition
      )
    end
    private_class_method :hand_over
  end
end
