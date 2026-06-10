module Identity
  class RegistrationsController < ApplicationController
    def new
    end

    def create
      result = RegisterUser.call(name: params[:name], email: params[:email], password: params[:password])
      if result.success?
        session[:user_id] = result.value
        redirect_to root_path, notice: "Welcome to Scorekeepr!"
      else
        flash.now[:alert] = result.error
        render :new, status: :unprocessable_entity
      end
    end
  end
end
