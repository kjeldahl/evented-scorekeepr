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
      session.delete(:user_id)
      redirect_to login_path, notice: "Signed out."
    end
  end
end
