module Scoreboards
  # Live updates for the TV dashboard: subscribes the viewer to the league's
  # event-tag stream ("events:league:{id}", broadcast by the bridge in
  # config/initializers/event_store_broadcasts.rb). Enforces the same
  # view-only member-or-super-admin gate as TvController with the slice's
  # own folds; failed gates reject the subscription.
  class TvChannel < ApplicationCable::Channel
    def subscribed
      return reject unless viewer_allowed?

      stream_from "events:league:#{params[:league_id]}"
    end

    private

    def viewer_allowed?
      Membership.member?(account_id: params[:account_id], user_id: current_user_id) ||
        SuperAdmin.super_admin?(user_id: current_user_id)
    end
  end
end
