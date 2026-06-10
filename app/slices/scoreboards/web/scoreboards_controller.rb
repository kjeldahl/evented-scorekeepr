module Scoreboards
  class ScoreboardsController < BaseController
    before_action :require_account_member!

    def show
      @league = LeagueOverview.find(league_id: params[:league_id], account_id: params[:account_id])
      return redirect_to account_path(params[:account_id]), alert: "the league was not found" unless @league

      @rows = Scoreboard.rows(@league)
      @recent_matches = RecentMatches.lines(@league.league_id)
    end

    private

    # Membership is enforced per slice with its own fold (docs/ARCHITECTURE.md):
    # non-members are sent back to the dashboard and never see the league.
    def require_account_member!
      return if Membership.member?(account_id: params[:account_id], user_id: current_user.id)

      redirect_to root_path, alert: "only members can view this league"
    end
  end
end
