# Super admin handoff (docs/DOMAIN.md § Super admin). Acts on the *real*
# login (session[:user_id]), not the impersonated member, since the actor is
# the super admin even mid-impersonation. The command is the consistency
# boundary; the before_action only refuses early for UX.
module Identity
  class SuperAdminHandoffsController < ApplicationController
    before_action :require_authentication
    before_action :require_super_admin!

    def new
    end

    def create
      result = HandOffSuperAdmin.call(
        from_user_id: session[:user_id], reauthenticated: reauthenticated?,
        to_email: params[:email], impersonation_id: session[:impersonation_id]
      )
      if result.success?
        forget_impersonation
        redirect_to root_path, notice: "Super admin status handed off."
      else
        flash.now[:alert] = result.error
        render :new, status: :unprocessable_entity
      end
    end

    private

    # The super admin proves identity with their own password; the command
    # only learns the outcome.
    def reauthenticated?
      AuthenticateUser.call(email: Users.find(session[:user_id]).email, password: params[:password]).success?
    end

    def require_super_admin!
      return if EventStore.project(CurrentSuperAdmin.projection) == session[:user_id]

      redirect_to root_path, alert: HandOffSuperAdmin::NOT_SUPER_ADMIN
    end
  end
end
