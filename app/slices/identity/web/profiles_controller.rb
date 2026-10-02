# The signed-in user's profile page: shows who they are and lets them set
# the handle displayed instead of their name wherever players are shown.
module Identity
  class ProfilesController < ApplicationController
    before_action :require_authentication

    before_action :load_super_admin, only: %i[show update]

    def show
    end

    def update
      result = SetHandle.call(user_id: current_user.id, handle: params[:handle])
      if result.success?
        redirect_to profile_path, notice: "Handle saved."
      else
        flash.now[:alert] = result.error
        render :show, status: :unprocessable_entity
      end
    end

    private

    # True only for the current super admin (never while impersonating, since
    # current_user is then the impersonated member): shows the handoff form.
    def load_super_admin
      @super_admin = CurrentSuperAdmin.holder == current_user.id
    end
  end
end
