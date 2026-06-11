# Development tooling (routed outside production only): accepts an outgoing
# invitation on behalf of the invited player, from the account page.
module Accounts
  class OnBehalfAcceptancesController < BaseController
    before_action :require_account_member!

    def create
      result = AcceptInvitationOnBehalf.call(invitation_id: params[:invitation_id])
      if result.success?
        redirect_to account_path(params[:account_id]), notice: "Invitation accepted on behalf of the invited player."
      else
        redirect_to account_path(params[:account_id]), alert: result.error
      end
    end

    private

    def require_account_member!
      return if Membership.member?(account_id: params[:account_id], user_id: current_user.id)

      redirect_to root_path, alert: "Only account members can view this account."
    end
  end
end
