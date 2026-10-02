# frozen_string_literal: true

# Shared world helpers for all slices' step definitions.
#
# Scenarios refer to people by display name ("Alice"); the per-scenario
# `users` registry maps those names to their credentials so later steps can
# sign them in without repeating emails/passwords.
#
# Public helper API (reuse these in other slices' steps):
#   users                                       # name => { email:, password: }
#   remember_user(name, email:, password:)      # record credentials only
#   register_user(name, email:, password:)      # register via the domain command + remember
#   grant_super_admin(name)                     # grant super admin via the domain command
#   hand_off_via_form(sender, email)            # hand super admin off through the real form
#   attempt_hand_off(sender, email, password:)  # POST a handoff directly (rejections render flash)
#   sign_up(name, email:, password:)            # register through the real /signup UI + remember
#   sign_in(name)                               # sign in through the real /login UI
#   sign_out                                    # sign out via the layout's Sign out button
#   user_id_for(name)                           # the registered user's id (from the event store)
#   registered_user_data(email:)                # UserRegistered event data for an email, or nil
#   submit_form(label)                          # click_button tolerating a not-yet-built redirect target
#   signed_in_as?(name)                         # current session check via the layout nav
#   expect_signed_in_as(name) / expect_signed_out
module ScorekeeprWorld
  def users
    @users ||= {}
  end

  def remember_user(name, email:, password:)
    users[name] = { email: email.strip.downcase, password: password }
  end

  def register_user(name, email:, password:)
    result = Identity::RegisterUser.call(name:, email:, password:)
    raise "could not register #{name}: #{result.error}" if result.failure?

    remember_user(name, email:, password:)
    result.value
  end

  # Granting has no web UI and no route (docs/DOMAIN.md § Super admin), so
  # the step calls the domain command directly, like register_user does.
  def attempt_super_admin_grant(name)
    Identity::GrantSuperAdmin.call(user_id: user_id_for(name))
  end

  def super_admin?(name)
    EventStore.decide(super_admin: Identity::CurrentSuperAdmin.projection).states.fetch(:super_admin) == user_id_for(name)
  end

  def grant_super_admin(name)
    result = attempt_super_admin_grant(name)
    raise "could not grant super admin to #{name}: #{result.error}" if result.failure?
  end

  # Signs in unless already acting as that user. While impersonating, the nav
  # shows the member, so an in-effect impersonation banner also counts as the
  # super admin's own session (signing in again would not end it anyway).
  def ensure_signed_in(name)
    return if signed_in_as?(name)

    visit "/"
    sign_in(name) unless page.has_css?(".impersonation-banner", wait: 0)
  end

  def hand_off_via_form(sender, email, password: users.fetch(sender).fetch(:password))
    ensure_signed_in(sender)
    visit "/super_admin_handoff/new"
    fill_in "Recipient email", with: email
    fill_in "Your password", with: password
    click_button "Hand off"
  end

  def attempt_hand_off(sender, email, password: users.fetch(sender).fetch(:password))
    ensure_signed_in(sender)
    page.driver.submit :post, "/super_admin_handoff", { email:, password: }
  end

  def sign_up(name, email:, password:)
    visit "/signup"
    fill_in "Name", with: name
    fill_in "Email", with: email
    fill_in "Password", with: password
    submit_form "Sign up"
    remember_user(name, email:, password:)
  end

  def sign_in(name)
    credentials = users.fetch(name) { raise "unknown user #{name.inspect} — register them first" }
    visit "/login"
    fill_in "Email", with: credentials[:email]
    fill_in "Password", with: credentials[:password]
    submit_form "Sign in"
  end

  # The layout shows the Sign out button on every page; visit one that is
  # already implemented so the click does not depend on the current page.
  def sign_out
    visit "/signup"
    click_button "Sign out"
  end

  def user_id_for(name)
    email = users.fetch(name).fetch(:email)
    data = registered_user_data(email:) or raise "#{name} (#{email}) is not registered"
    data[:user_id]
  end

  def registered_user_data(email:)
    query = DcbEventStore::Query.new([
      DcbEventStore::QueryItem.new(event_types: %w[UserRegistered], tags: [ "user_email:#{email.strip.downcase}" ])
    ])
    EventStore.read(query).last&.data
  end

  # Successful sign-up/sign-in redirects to root (the accounts dashboard),
  # which is built by a later slice. Rack-test stores the session cookie from
  # the redirect response before following it, so the signed-in session
  # survives even when rendering the redirect target raises. Swallow only
  # that missing-page error; assertions then visit a page that exists
  # (see expect_signed_in_as).
  def submit_form(label)
    click_button label
  rescue ActionDispatch::MissingController, ActionController::RoutingError
    nil
  end

  # /signup always renders (no redirect-if-signed-in), so the layout nav
  # reliably reflects session state there.
  def signed_in_as?(name)
    visit "/signup"
    page.has_css?(".site-nav", text: name, wait: 0) && page.has_button?("Sign out", wait: 0)
  end

  def expect_signed_in_as(name)
    visit "/signup"
    expect(page).to have_css(".site-nav", text: name)
    expect(page).to have_button("Sign out")
  end

  def expect_signed_out
    visit "/signup"
    expect(page).to have_css(".site-nav a", text: "Sign in")
    expect(page).to have_no_button("Sign out")
  end
end

World(ScorekeeprWorld)
