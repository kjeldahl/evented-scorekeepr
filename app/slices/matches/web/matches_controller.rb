module Matches
  class MatchesController < BaseController
    before_action :require_account_member!
    before_action :load_form

    def new
    end

    def create
      result = RegisterMatch.call(user_id: current_user.id, **match_params)
      if result.success?
        redirect_to account_league_scoreboard_path(params[:account_id], params[:league_id]),
                    notice: "Match registered"
      else
        flash.now[:alert] = result.error
        render :new, status: :unprocessable_entity
      end
    end

    private

    def match_params
      { league_id: params[:league_id], account_id: params[:account_id],
        home_player_ids: [ params[:home_player_1_id], params[:home_player_2_id] ],
        away_player_ids: [ params[:away_player_1_id], params[:away_player_2_id] ],
        home_score: params[:home_score], away_score: params[:away_score] }
    end

    # The form needs the league's name for its heading and the account's
    # members for the player selects; both render again on a failed create.
    def load_form
      @league = League.find(league_id: params[:league_id], account_id: params[:account_id])
      return if @league

      redirect_to account_path(params[:account_id]), alert: "the league was not found"
    end

    def members
      @members ||= AccountMembers.for_account(params[:account_id])
    end
    helper_method :members

    # Membership is enforced per slice with its own fold (docs/ARCHITECTURE.md):
    # non-members are sent back to the dashboard and never reach the form.
    def require_account_member!
      return if Membership.member?(account_id: params[:account_id], user_id: current_user.id)

      redirect_to root_path, alert: "only members can register matches"
    end
  end
end
