module ApplicationCable
  # Authenticates the websocket at /cable: identifies the connecting user by
  # the user id in the encrypted session cookie (the identity slice owns
  # *writing* session[:user_id]); unauthenticated connections are rejected.
  # Shared web infrastructure (root package) — no domain logic, no slice
  # references; slice channels enforce their own gates on top.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user_id

    def connect
      self.current_user_id = session_user_id
      reject_unauthorized_connection unless current_user_id
    end

    private

    # The cookie session store round-trips the session hash with string keys.
    def session_user_id
      cookies.encrypted[session_cookie_key]&.[]("user_id")
    end

    def session_cookie_key
      Rails.application.config.session_options[:key]
    end
  end
end
