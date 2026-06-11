# Revokes a pending outgoing invitation from the account page.
module Accounts
  class InvitationRevocationsController < BaseController
    before_action :require_account_member!

    def create
      result = RevokeInvitation.call(invitation_id: params[:invitation_id],
                                     account_id: params[:account_id], user_id: current_user.id)
      if result.success?
        redirect_to account_path(params[:account_id]), notice: "Invitation revoked."
      else
        redirect_to account_path(params[:account_id]), alert: result.error
      end
    end

    private

    def require_account_member!
      return if Membership.member?(account_id: params[:account_id], user_id: current_user.id)

      redirect_to root_path, alert: "only members can revoke invitations"
    end
  end
end
