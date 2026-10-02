# Hands the super admin status to another user by email (profile page form).
# The command enforces that only the current super admin may do so.
module Identity
  class SuperAdminHandoffsController < ApplicationController
    before_action :require_authentication

    def create
      result = HandOffSuperAdmin.call(actor_user_id: current_user.id, email: params[:email])
      if result.success?
        redirect_to profile_path, notice: "Super admin status handed over."
      else
        redirect_to profile_path, alert: result.error
      end
    end
  end
end
