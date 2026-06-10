module Accounts
  class InvitationAcceptancesController < BaseController
    def create
      result = AcceptInvitation.call(invitation_id: params[:invitation_id],
                                     user_id: current_user.id, user_email: current_user.email)
      if result.success?
        redirect_to account_path(result.value), notice: "Invitation accepted."
      else
        redirect_to root_path, alert: result.error
      end
    end
  end
end
