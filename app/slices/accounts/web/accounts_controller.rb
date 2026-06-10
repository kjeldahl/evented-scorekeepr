module Accounts
  class AccountsController < BaseController
    before_action :require_account_member!, only: :show

    def new
    end

    def create
      result = CreateAccount.call(name: params[:name], owner_user_id: current_user.id)
      if result.success?
        redirect_to account_path(result.value), notice: "Account created."
      else
        flash.now[:alert] = result.error
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @account = Account.find(params[:id])
      @members = Members.for_account(params[:id])
      @leagues = AccountLeagues.for_account(params[:id])
    end

    private

    # Membership is enforced per slice with its own fold (docs/ARCHITECTURE.md):
    # non-members are sent back to the dashboard and never see the account.
    def require_account_member!
      return if Membership.member?(account_id: params[:id], user_id: current_user.id)

      redirect_to root_path, alert: "Only account members can view this account."
    end
  end
end
