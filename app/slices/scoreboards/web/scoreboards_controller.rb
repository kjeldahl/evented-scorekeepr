module Scoreboards
  class ScoreboardsController < BaseController
    before_action :require_account_member!

    def show
      @league = LeagueOverview.find(league_id: params[:league_id], account_id: params[:account_id])
      return redirect_to account_path(params[:account_id]), alert: "the league was not found" unless @league

      @rows = Scoreboard.rows(@league)
      @recent_matches = RecentMatches.entries(@league.league_id)
    end

    private

    # Membership is enforced per slice with its own fold (docs/ARCHITECTURE.md).
    # This show gate additionally opens for super admins (view-only access);
    # the view uses @member to hide write affordances from non-member viewers.
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
