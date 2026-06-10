module Accounts
  class InvitationsController < BaseController
    before_action :require_account_member!
    before_action :load_account

    def new
    end

    def create
      result = InvitePlayer.call(account_id: params[:account_id], email: params[:email],
                                 invited_by_user_id: current_user.id)
      if result.success?
        redirect_to account_path(params[:account_id]), notice: "Invitation sent."
      else
        flash.now[:alert] = result.error
        render :new, status: :unprocessable_entity
      end
    end

    private

    def require_account_member!
      return if Membership.member?(account_id: params[:account_id], user_id: current_user.id)

      redirect_to root_path, alert: "only members can invite players"
    end

    def load_account
      @account = Account.find(params[:account_id])
    end
  end
end
