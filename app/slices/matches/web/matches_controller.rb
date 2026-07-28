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
      render @multiplayer ? :new_multiplayer : :new
    end

    def create
      if @league.multiplayer_league?
        result = RegisterMultiplayerMatch.call(user_id: current_user.id, **multiplayer_params)
      else
        result = RegisterMatch.call(user_id: current_user.id, **register_match_params)
      end
      if result.success?
        redirect_to account_league_scoreboard_path(params[:account_id], params[:league_id]),
                    notice: "Match registered"
      else
        @multiplayer = @league.multiplayer_league?
        flash.now[:alert] = result.error
        render @multiplayer ? :new_multiplayer : :new, status: :unprocessable_entity
      end
    end

    def edit
      load_match or return
      @multiplayer = @match.is_a?(MultiplayerMatchDetails::Details)
    end

    def update
      perform_match_action(:update, "Match updated") or return
    end

    def destroy
      perform_match_action(:destroy, "Match deleted") or return
    end

    private

    # Routes the action through the match-type-specific dispatcher,
    # then redirects or re-renders.
    def perform_match_action(action, notice)
      load_match or return
      @multiplayer = @match.is_a?(MultiplayerMatchDetails::Details)
      handle_result(dispatch_command(action), notice)
    end

    # Dispatches to the correct command based on action and match type.
    # Maps (action, type) pairs so the lookup is O(1) and the method
    # has a cyclomatic complexity of 2 (the hash lookup path).
    def dispatch_command(action)
      table = {
        true => {
          update: -> { CorrectMultiplayerMatch.call(match_id: @match.match_id, user_id: current_user.id, **correct_multi_params) },
          destroy: -> { DeleteMultiplayerMatch.call(match_id: @match.match_id, user_id: current_user.id, **match_scope) }
        },
        false => {
          update: -> { EditMatch.call(match_id: @match.match_id, user_id: current_user.id, **edit_params) },
          destroy: -> { DeleteMatch.call(match_id: @match.match_id, user_id: current_user.id, **match_scope) }
        }
      }
      table[@multiplayer][action].call
    end

    # Redirects on success; re-renders the edit form on failure.
    def handle_result(result, notice)
      if result.success?
        redirect_to account_league_scoreboard_path(params[:account_id], params[:league_id]),
                    notice: notice
      else
        render_edit_error(result.error)
      end
    end

    # A failed edit or delete re-renders the edit form (which hosts both
    # actions) with the error; a match that has since vanished sends the
    # player back to the scoreboard instead.
    def render_edit_error(message)
      return unless load_match

      flash.now[:alert] = message
      @multiplayer = @match.is_a?(MultiplayerMatchDetails::Details)
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

    def multiplayer_scores_params
      raw = params[:scores] || {}
      h = raw.is_a?(ActionController::Parameters) ? raw.to_unsafe_h : raw
      h.to_h { |k, v| [ k.to_s, v ] }
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
