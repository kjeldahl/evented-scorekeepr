module Matches
  class MatchesController < BaseController
    # Registering is member-gated; editing and deleting are authorised by
    # match participation in the EditMatch/DeleteMatch commands (a non-member
    # is simply not a player), so they need no membership before_action - only
    # sign-in.
    before_action :require_account_member!, only: %i[new create]
    before_action :load_form

    def new
      @multiplayer = @league.multiplayer_league?
    end

    def create
      if @league.multiplayer_league?
        result = RegisterMultiplayerMatch.call(user_id: current_user.id, **multiplayer_params)
      else
        result = RegisterMatch.call(user_id: current_user.id, **match_params)
      end
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
      @multiplayer = @match.is_a?(Scoreboards::MultiplayerMatch)
    end

    def update
      if @multiplayer
        result = CorrectMultiplayerMatch.call(match_id: params[:id], user_id: current_user.id, **correct_multi_params)
      else
        result = EditMatch.call(match_id: params[:id], user_id: current_user.id, **edit_params)
      end
      if result.success?
        redirect_to account_league_scoreboard_path(params[:account_id], params[:league_id]),
                    notice: "Match updated"
      else
        render_edit_error(result.error)
      end
    end

    def destroy
      if @multiplayer
        result = DeleteMultiplayerMatch.call(match_id: params[:id], user_id: current_user.id, **match_scope)
      else
        result = DeleteMatch.call(match_id: params[:id], user_id: current_user.id, **match_scope)
      end
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

    def load_match
      @match = find_match(params[:id])
      return @match if @match

      redirect_to account_league_scoreboard_path(params[:account_id], params[:league_id]),
                  alert: "the match was not found"
      nil
    end

    def find_match(match_id)
      MatchDetails.find(match_id:) || MultiplayerMatchDetails.find(match_id:)
    end

    def edit_params
      match_scope.merge(home_score: params[:home_score], away_score: params[:away_score])
    end

    def correct_multi_params
      match_scope.merge(player_scores: multiplayer_scores_params)
    end

    def multiplayer_params
      player_ids = params[:player_ids] || []
      scores_raw = params[:scores] || {}
      scores_hash = scores_raw.is_a?(ActionController::Parameters) ? scores_raw.to_unsafe_h : scores_raw
      player_scores = scores_hash.to_h { |k, v| [ k.to_s, v ] }
      { league_id: params[:league_id], account_id: params[:account_id],
        user_id: current_user.id, player_ids:, player_scores: }
    end

    def match_scope
      { league_id: params[:league_id], account_id: params[:account_id] }
    end

    # The form needs the league's name for its heading and the account's
    # members for the player selects; both render again on a failed create.
    def load_form
      @league = Leagues::League.find(params[:league_id])
      return if @league

      redirect_to account_path(params[:account_id]), alert: "the league was not found"
    end

    def members
      @members ||= AccountMembers.for_account(params[:account_id])
    end
    helper_method :members

    # The players shown in the multiplayer form: all account members, prefilled
    # from a failed submission if present.
    def form_players
      @form_players ||= if params[:scores]
        params[:scores].keys.map do |player_id|
          { player_id:, score: params[:scores][player_id] }
        end
      else
        members.map { |m| { player_id: m.user_id, score: nil } }
      end
    end
    helper_method :form_players

    # Membership is enforced per slice with its own fold (docs/ARCHITECTURE.md):
    # non-members are sent back to the dashboard and never reach the form.
    def require_account_member!
      return if Membership.member?(account_id: params[:account_id], user_id: current_user.id)

      redirect_to root_path, alert: "only members can register matches"
    end
  end
end
