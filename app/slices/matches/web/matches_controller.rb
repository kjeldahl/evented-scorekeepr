module Matches
  class MatchesController < BaseController
    # Registering is member-gated; editing and deleting are authorised by
    # match participation in the EditMatch/DeleteMatch commands (a non-member
    # is simply not a player), so they need no membership before_action - only
    # sign-in.
    before_action :require_account_member!, only: %i[new create]
    before_action :load_form

    def new
      render register_form
    end

    # The league's match type picks the register command, just as the match's
    # own kind picks the correction command in #update.
    def create
      handle_registration(registration)
    end

    def edit
      load_match or return
      @multiplayer = @match.multiplayer?
    end

    # The two forms the edit page hosts submit different fields, so the form
    # the match belongs to picks the correction command. Deleting takes the
    # same input for both kinds, so DeleteMatch handles either.
    def update
      load_match or return
      handle_result(correction, "Match updated")
    end

    def destroy
      handle_result(DeleteMatch.call(match_id: params[:id], user_id: current_user.id, **match_scope), "Match deleted")
    end

    private

    def registration
      return RegisterMultiplayerMatch.call(user_id: current_user.id, **multiplayer_params) if @league.multiplayer_league?

      RegisterMatch.call(user_id: current_user.id, **register_match_params)
    end

    def correction
      return CorrectMultiplayerMatch.call(match_id: @match.match_id, user_id: current_user.id, **correct_multi_params) if @match.multiplayer?

      EditMatch.call(match_id: @match.match_id, user_id: current_user.id, **edit_params)
    end

    # A failed registration re-renders the register form it came from.
    def handle_registration(result)
      return redirect_to_scoreboard("Match registered") if result.success?

      flash.now[:alert] = result.error
      render register_form, status: :unprocessable_entity
    end

    # The two match kinds have their own register form; the league picks it,
    # both when opening the page and when a failed registration returns to it.
    def register_form
      @multiplayer = @league.multiplayer_league?
      @multiplayer ? :new_multiplayer : :new
    end

    # A failed correction or deletion re-renders the edit form instead.
    def handle_result(result, notice)
      return redirect_to_scoreboard(notice) if result.success?

      render_edit_error(result.error)
    end

    # Every command in this controller ends on the league's scoreboard.
    def redirect_to_scoreboard(notice)
      redirect_to account_league_scoreboard_path(params[:account_id], params[:league_id]), notice: notice
    end

    # A failed edit or delete re-renders the edit form (which hosts both
    # actions) with the error; a match that has since vanished sends the
    # player back to the scoreboard instead.
    def render_edit_error(message)
      return unless load_match

      flash.now[:alert] = message
      @multiplayer = @match.multiplayer?
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
      match_scope.merge(player_ids: params[:player_ids] || [],
                        player_scores: multiplayer_scores_params)
    end

    # The per-player score fields arrive as nested params; the commands take a
    # plain string-keyed hash.
    def multiplayer_scores_params
      scores = params.fetch(:scores, ActionController::Parameters.new)
      scores.to_unsafe_h.to_h { |player_id, score| [ player_id.to_s, score ] }
    end

    def register_match_params
      match_scope.merge(home_player_ids: home_player_ids,
                        away_player_ids: away_player_ids,
                        home_score: params[:home_score],
                        away_score: params[:away_score])
    end

    def home_player_ids
      [ params[:home_player_1_id], params[:home_player_2_id] ].compact
    end

    def away_player_ids
      [ params[:away_player_1_id], params[:away_player_2_id] ].compact
    end

    def match_scope
      { league_id: params[:league_id], account_id: params[:account_id] }
    end

    # The form needs the league's name for its heading and the account's
    # members for the player selects; both render again on a failed create.
    def load_form
      @league = Matches::League.find(league_id: params[:league_id], account_id: params[:account_id])
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
