# Lets the signed-in member leave the account from the account page.
module Accounts
  class AccountLeavingsController < BaseController
    def create
      result = LeaveAccount.call(account_id: params[:account_id], user_id: current_user.id)
      if result.success?
        redirect_to root_path, notice: "You left the account."
      else
        redirect_to root_path, alert: result.error
      end
    end
  end
end
