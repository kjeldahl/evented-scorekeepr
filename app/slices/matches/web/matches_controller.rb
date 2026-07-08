module Matches
  class MatchesController < BaseController
    # Registering is member-gated; editing and deleting are authorised by
    # match participation in the EditMatch/DeleteMatch commands (a non-member
    # is simply not a player), so they need no membership before_action - only
    # sign-in.
    before_action :require_account_member!, only: %i[new create]
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

    def edit
      load_match or return
    end

    def update
      result = EditMatch.call(match_id: params[:id], user_id: current_user.id, **edit_params)
      if result.success?
        redirect_to account_league_scoreboard_path(params[:account_id], params[:league_id]),
                    notice: "Match updated"
      else
        render_edit_error(result.error)
      end
    end

    def destroy
      result = DeleteMatch.call(match_id: params[:id], user_id: current_user.id, **match_scope)
      if result.success?
        redirect_to account_league_scoreboard_path(params[:account_id], params[:league_id]),
                    notice: "Match deleted"
      else
        render_edit_error(result.error)
      end
    end

    private

    # A failed edit or delete re-renders the edit form (which hosts both
    # actions) with the error; a match that has since vanished sends the
    # player back to the scoreboard instead.
    def render_edit_error(message)
      return unless load_match

      flash.now[:alert] = message
      render :edit, status: :unprocessable_entity
    end

    def edit_params
      match_scope.merge(home_score: params[:home_score], away_score: params[:away_score])
    end

    def match_scope
      { league_id: params[:league_id], account_id: params[:account_id] }
    end

    # The edit form shows the fixed sides by name and prefills the score;
    # an unknown match sends the editor back to the scoreboard.
    def load_match
      @match = MatchDetails.find(match_id: params[:id])
      return @match if @match

      redirect_to account_league_scoreboard_path(params[:account_id], params[:league_id]),
                  alert: "the match was not found"
      nil
    end

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
