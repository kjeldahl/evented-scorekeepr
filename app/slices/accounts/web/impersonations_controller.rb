module Accounts
  # Starts and stops a super admin's impersonation session (docs/DOMAIN.md
  # § Impersonation). Sign-in is required (BaseController); the super admin
  # invariant lives in the StartImpersonation command, so a non-super-admin
  # who POSTs here is rejected with the command's message. The session keeps
  # the real login in session[:user_id] and records who is being impersonated
  # in session[:impersonated_user_id]; ApplicationController#current_user then
  # resolves to the member for the rest of the session.
  class ImpersonationsController < BaseController
    def create
      result = StartImpersonation.call(
        super_admin_user_id: current_user.id,
        account_id: params[:account_id],
        impersonated_user_id: params[:user_id]
      )
      if result.success?
        start_session(result.value, params[:user_id])
        redirect_to account_path(params[:account_id]), notice: "You are now impersonating."
      else
        redirect_to account_path(params[:account_id]), alert: result.error
      end
    end

    def destroy
      ImpersonationSession.stop(super_admin_user_id: session[:user_id], impersonation_id: session[:impersonation_id])
      forget_impersonation
      redirect_to root_path, notice: "Stopped impersonating."
    end

    private

    def start_session(impersonation_id, impersonated_user_id)
      session[:impersonation_id] = impersonation_id
      session[:impersonated_user_id] = impersonated_user_id
    end
  end
end
