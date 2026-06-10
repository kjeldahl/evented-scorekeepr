# Slice-local authentication gate for the matches slice. The features
# phrase the guest rejection as "you must be signed in", which differs from
# ApplicationController#require_authentication's copy, so this slice owns
# its own before_action instead of changing the shared helper.
module Matches
  class BaseController < ApplicationController
    before_action :require_sign_in

    private

    def require_sign_in
      return if signed_in?

      redirect_to login_path, alert: "you must be signed in"
    end
  end
end
