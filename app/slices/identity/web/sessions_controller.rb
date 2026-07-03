module Identity
  class SessionsController < ApplicationController
    def new
    end

    def create
      result = AuthenticateUser.call(email: params[:email], password: params[:password])
      if result.success?
        session[:user_id] = result.value
        redirect_to root_path, notice: "Signed in."
      else
        flash.now[:alert] = result.error
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      # Signing out ends the super admin's own login, so it must also end any
      # impersonation session (docs/DOMAIN.md § Impersonation): otherwise the
      # layout would render the impersonation notice for a signed-out (nil)
      # user. Ending is recorded in the audit trail before the keys are dropped.
      if impersonating?
        ImpersonationSession.stop(super_admin_user_id: session[:user_id], impersonation_id: session[:impersonation_id])
        forget_impersonation
      end
      session.delete(:user_id)
      redirect_to login_path, notice: "Signed out."
    end
  end
end
