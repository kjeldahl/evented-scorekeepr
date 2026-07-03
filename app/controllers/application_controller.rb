class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user, :signed_in?, :impersonating?

  # Publish the session's impersonation into request-scoped state so the
  # event-store audit hook can attribute writes made while impersonating back
  # to the real super admin (docs/DOMAIN.md § Impersonation).
  before_action :set_current_impersonation

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

  # The effective user for the request, resolved from the session via the
  # identity slice's public reader (Identity::Users.find returns a user value
  # object with id, name, email and handle, or nil). This is the only
  # cross-slice class reference allowed in the app.
  #
  # While a super admin is impersonating (docs/DOMAIN.md § Impersonation) the
  # effective user is the impersonated member: every slice sees that member as
  # the actor, so their commands run with the member's privileges and are
  # attributed to the member — no slice consults super admin status.
  def current_user
    return nil unless session[:user_id]

    @current_user ||= Identity::Users.find(session[:impersonated_user_id] || session[:user_id])
  end

  def signed_in?
    current_user.present?
  end

  # True while the session is impersonating a member (the layout shows the
  # notice + escape button whenever this holds).
  def impersonating?
    session[:impersonated_user_id].present?
  end

  def set_current_impersonation
    Current.impersonation =
      if impersonating?
        { impersonation_id: session[:impersonation_id],
          super_admin_user_id: session[:user_id],
          impersonated_user_id: session[:impersonated_user_id] }
      end
  end

  def require_authentication
    return if signed_in?

    redirect_to login_path, alert: "Please sign in to continue."
  end
end
