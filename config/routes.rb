# The full route map for Scorekeepr. Every route points at a slice
# controller ("identity/sessions" resolves to Identity::SessionsController).
# The table is documented in docs/ARCHITECTURE.md — keep both in sync.
Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # ActionCable websocket endpoint (live updates, e.g. the TV dashboard).
  # The engine's automatic internal mount is disabled in config/application.rb
  # so this explicit mount is the single source of truth.
  mount ActionCable.server => "/cable"

  # Identity slice: sign up, sign in / out.
  get    "signup", to: "identity/registrations#new"
  post   "signup", to: "identity/registrations#create"
  get    "login",  to: "identity/sessions#new"
  post   "login",  to: "identity/sessions#create"
  delete "logout", to: "identity/sessions#destroy"
  get    "profile", to: "identity/profiles#show", as: :profile
  post   "profile", to: "identity/profiles#update"
  get    "super_admin_handoff/new", to: "identity/super_admin_handoffs#new", as: :new_super_admin_handoff
  post   "super_admin_handoff", to: "identity/super_admin_handoffs#create", as: :super_admin_handoff

  # Accounts slice: dashboard, accounts, invitations, membership.
  root "accounts/dashboard#show"

  scope module: :accounts do
    # index is the super-admin-only all-accounts list (docs/DOMAIN.md § Super admin).
    resources :accounts, only: %i[index new create show] do
      resources :invitations, only: %i[new create]
    end

    post "accounts/:account_id/invitations/:invitation_id/revoke",
         to: "invitation_revocations#create", as: :revoke_account_invitation
    post "accounts/:account_id/leave", to: "account_leavings#create", as: :leave_account

    # Impersonation (docs/DOMAIN.md § Impersonation): a super admin starts a
    # session against a member from that account's members list; ending it is
    # whole-session, so the escape is a single account-independent route.
    post "accounts/:account_id/members/:user_id/impersonate",
         to: "impersonations#create", as: :impersonate_account_member
    delete "impersonation", to: "impersonations#destroy", as: :impersonation

    get  "invitations", to: "pending_invitations#index", as: :pending_invitations
    post "invitations/:invitation_id/accept", to: "invitation_acceptances#create", as: :accept_invitation
    post "invitations/:invitation_id/decline", to: "invitation_declines#create", as: :decline_invitation

    # Development tooling: accept an outgoing invitation on behalf of the
    # invited player. Not routed in production.
    unless Rails.env.production?
      post "accounts/:account_id/invitations/:invitation_id/accept_on_behalf",
           to: "on_behalf_acceptances#create", as: :accept_account_invitation_on_behalf
    end
  end

  # Leagues slice: create, rename and close leagues.
  scope module: :leagues do
    resources :accounts, only: [] do
      resources :leagues, only: %i[new create edit update] do
        post :close, on: :member
      end
    end
  end

  # Scoreboards slice: the league page (standings + recent matches) and the
  # TV dashboard (full-screen, read-only, live-updating via ActionCable push;
  # the version endpoint is the catch-up contract checked on (re)connect).
  get "accounts/:account_id/leagues/:league_id/scoreboard",
      to: "scoreboards/scoreboards#show", as: :account_league_scoreboard
  get "accounts/:account_id/leagues/:league_id/tv",
      to: "scoreboards/tv#show", as: :account_league_tv
  get "accounts/:account_id/leagues/:league_id/tv/version",
      to: "scoreboards/tv#version", as: :account_league_tv_version

  # Statistics slice: per-player league statistics.
  get "accounts/:account_id/leagues/:league_id/players/:player_id",
      to: "statistics/players#show", as: :account_league_player

  # Matches slice: register, correct and delete match results.
  scope module: :matches do
    resources :accounts, only: [] do
      resources :leagues, only: [] do
        resources :matches, only: %i[new create edit update destroy]
      end
    end
  end
end
