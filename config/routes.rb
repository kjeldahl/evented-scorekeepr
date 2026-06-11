# The full route map for Scorekeepr. Every route points at a slice
# controller ("identity/sessions" resolves to Identity::SessionsController).
# The table is documented in docs/ARCHITECTURE.md — keep both in sync.
Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Identity slice: sign up, sign in / out.
  get    "signup", to: "identity/registrations#new"
  post   "signup", to: "identity/registrations#create"
  get    "login",  to: "identity/sessions#new"
  post   "login",  to: "identity/sessions#create"
  delete "logout", to: "identity/sessions#destroy"

  # Accounts slice: dashboard, accounts, invitations, membership.
  root "accounts/dashboard#show"

  scope module: :accounts do
    resources :accounts, only: %i[new create show] do
      resources :invitations, only: %i[new create]
    end

    get  "invitations", to: "pending_invitations#index", as: :pending_invitations
    post "invitations/:invitation_id/accept", to: "invitation_acceptances#create", as: :accept_invitation

    # Development tooling: accept an outgoing invitation on behalf of the
    # invited player. Not routed in production.
    unless Rails.env.production?
      post "accounts/:account_id/invitations/:invitation_id/accept_on_behalf",
           to: "on_behalf_acceptances#create", as: :accept_account_invitation_on_behalf
    end
  end

  # Leagues slice: create and close leagues.
  scope module: :leagues do
    resources :accounts, only: [] do
      resources :leagues, only: %i[new create] do
        post :close, on: :member
      end
    end
  end

  # Scoreboards slice: the league page (standings + recent matches).
  get "accounts/:account_id/leagues/:league_id/scoreboard",
      to: "scoreboards/scoreboards#show", as: :account_league_scoreboard

  # Statistics slice: per-player league statistics.
  get "accounts/:account_id/leagues/:league_id/players/:player_id",
      to: "statistics/players#show", as: :account_league_player

  # Matches slice: register match results.
  scope module: :matches do
    resources :accounts, only: [] do
      resources :leagues, only: [] do
        resources :matches, only: %i[new create]
      end
    end
  end
end
