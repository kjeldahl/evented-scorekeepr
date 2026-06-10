# The landing page: the signed-in user's accounts and pending invitations.
module Accounts
  class DashboardController < BaseController
    def show
      @accounts = MyAccounts.for_user(current_user.id)
      @pending_invitations = PendingInvitations.for_email(current_user.email)
    end
  end
end
