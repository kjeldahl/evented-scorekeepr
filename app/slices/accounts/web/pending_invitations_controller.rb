# The signed-in user's pending invitations, looked up by their email.
module Accounts
  class PendingInvitationsController < BaseController
    def index
      @pending_invitations = PendingInvitations.for_email(current_user.email)
    end
  end
end
