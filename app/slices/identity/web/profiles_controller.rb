# The signed-in user's profile page: shows who they are and lets them set
# the handle displayed instead of their name wherever players are shown.
module Identity
  class ProfilesController < ApplicationController
    before_action :require_authentication

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
  end
end
