# Declines a pending invitation as the signed-in invited user.
module Accounts
  class InvitationDeclinesController < BaseController
    def create
      result = DeclineInvitation.call(invitation_id: params[:invitation_id],
                                      user_id: current_user.id, user_email: current_user.email)
      if result.success?
        redirect_to root_path, notice: "Invitation declined."
      else
        redirect_to root_path, alert: result.error
      end
    end
  end
end
