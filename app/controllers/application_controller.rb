class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user, :signed_in?

  # Slice views live in app/slices/<slice>/views/<resource>/ and every slice
  # views directory is on the view path, so templates are also looked up
  # without the slice module prefix ("sessions/new" as well as
  # "identity/sessions/new"). Resource directory names must therefore be
  # unique across slices (see docs/ARCHITECTURE.md).
  def self.local_prefixes
    prefixes = super
    prefixes += [ controller_path.rpartition("/").last ] if controller_path.include?("/")
    prefixes
  end

  private

  # The signed-in user, resolved from the session via the identity slice's
  # public reader (Identity::Users.find returns a user value object with
  # id, name and email, or nil). This is the only cross-slice class
  # reference allowed in the app.
  def current_user
    return nil unless session[:user_id]

    @current_user ||= Identity::Users.find(session[:user_id])
  end

  def signed_in?
    current_user.present?
  end

  def require_authentication
    return if signed_in?

    redirect_to login_path, alert: "Please sign in to continue."
  end
end
