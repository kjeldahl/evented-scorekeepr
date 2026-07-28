module Scoreboards
  class TvController < BaseController
    before_action :require_account_member!

    layout "tv"

    def show
      @league = LeagueOverview.find(league_id: params[:league_id], account_id: params[:account_id])
      return redirect_to account_path(params[:account_id]), alert: "the league was not found" unless @league

      @rows = Scoreboard.rows(@league)
      @leader = TvSpotlights.leader(@rows)
      @hot_streak = TvSpotlights.hot_streak(@rows)
      @recent_matches = RecentMatches.lines(@league.league_id, game_type: @league.game_type)
      @version = LeagueVersion.version(league_id: @league.league_id)
    end

    def version
      render json: { version: LeagueVersion.version(league_id: params[:league_id]) }
    end

    private

    # Membership is enforced per slice with its own fold (docs/ARCHITECTURE.md).
    # This view-only gate additionally opens for super admins; the TV page has
    # no write affordances, so the view needs no member distinction.
    def require_account_member!
      @member = Membership.member?(account_id: params[:account_id], user_id: current_user.id)
      return if viewer_allowed?

      redirect_to root_path, alert: "only members can view this league"
    end

    def viewer_allowed?
      @member || SuperAdmin.super_admin?(user_id: current_user.id)
    end
  end
end
