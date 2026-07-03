module Accounts
  class AccountsController < BaseController
    before_action :require_account_member!, only: :show
    before_action :require_super_admin!, only: :index

    def index
      @accounts = AllAccounts.all
    end

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
      @outgoing_invitations = OutgoingInvitations.for_account(params[:id])
    end

    private

    # Membership is enforced per slice with its own fold (docs/ARCHITECTURE.md).
    # This show gate additionally opens for super admins (view-only access);
    # the view uses @member to hide write affordances from non-member viewers,
    # and @super_admin to offer the impersonate button on member rows.
    def require_account_member!
      @member = Membership.member?(account_id: params[:id], user_id: current_user.id)
      @super_admin = SuperAdmin.super_admin?(user_id: current_user.id)
      return if viewer_allowed?

      redirect_to root_path, alert: "Only account members can view this account."
    end

    def viewer_allowed?
      @member || @super_admin
    end

    # The all-accounts list is the one super-admin-only page
    # (docs/ARCHITECTURE.md § Super admin read access).
    def require_super_admin!
      return if SuperAdmin.super_admin?(user_id: current_user.id)

      redirect_to root_path, alert: "Only super admins can view all accounts."
    end
  end
end
