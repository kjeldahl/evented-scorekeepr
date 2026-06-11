module Statistics
  class PlayersController < BaseController
    before_action :require_account_member!

    def show
      @league = LeagueConfig.find(league_id: params[:league_id], account_id: params[:account_id])
      return redirect_to account_path(params[:account_id]), alert: "the league was not found" unless @league

      load_player_page
    end

    private

    def load_player_page
      @page = PlayerPage.find(league: @league, player_id: params[:player_id])
      return if @page

      redirect_to account_league_scoreboard_path(params[:account_id], params[:league_id]),
                  alert: "the player was not found"
    end

    # Membership is enforced per slice with its own fold (docs/ARCHITECTURE.md):
    # non-members are sent back to the dashboard and never see the player page.
    def require_account_member!
      return if Membership.member?(account_id: params[:account_id], user_id: current_user.id)

      redirect_to root_path, alert: "only members can view this league"
    end
  end
end
