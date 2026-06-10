module Leagues
  class LeaguesController < BaseController
    before_action :require_account_member!

    def new
    end

    def create
      result = CreateLeague.call(user_id: current_user.id, **league_params)
      if result.success?
        redirect_to account_league_scoreboard_path(params[:account_id], result.value), notice: "League created."
      else
        flash.now[:alert] = result.error
        render :new, status: :unprocessable_entity
      end
    end

    def close
      result = CloseLeague.call(league_id: params[:id], account_id: params[:account_id], user_id: current_user.id)
      scoreboard = account_league_scoreboard_path(params[:account_id], params[:id])
      if result.success?
        redirect_to scoreboard, notice: "League closed."
      else
        redirect_to scoreboard, alert: result.error
      end
    end

    private

    def league_params
      { account_id: params[:account_id], name: params[:name], game_type: params[:game_type],
        starting_points: params[:starting_points], stake_percentage: params[:stake_percentage] }
    end

    # Membership is enforced per slice with its own fold (docs/ARCHITECTURE.md):
    # non-members are sent back to the dashboard and never reach the league.
    def require_account_member!
      return if Membership.member?(account_id: params[:account_id], user_id: current_user.id)

      redirect_to root_path, alert: membership_alert
    end

    def membership_alert
      action_name == "close" ? "only members can close leagues" : "only members can create leagues"
    end
  end
end
