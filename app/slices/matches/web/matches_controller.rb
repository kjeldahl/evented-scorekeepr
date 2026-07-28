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
      render new_view
    end

    def create
      @multiplayer = @league.multiplayer_league?
      handle_create_result(dispatch_register)
    end

    def edit
      load_match or return
    end

    def update
      perform_match_action(:update, "Match updated") or return
    end

    def destroy
      perform_match_action(:destroy, "Match deleted") or return
    end

    private

    # The registration form for this league's match type; both the initial
    # GET and a rejected POST render it.
    def new_view
      @multiplayer ? :new_multiplayer : :new
    end

    # Dispatches to the correct register command for the league's match type.
    def dispatch_register
      table = {
        true => -> { RegisterMultiplayerMatch.call(user_id: current_user.id, **multiplayer_params) },
        false => -> { RegisterMatch.call(user_id: current_user.id, **register_match_params) }
      }
      table[@multiplayer].call
    end

    # Redirects on success; re-renders the registration form on failure.
    def handle_create_result(result)
      return redirect_to_scoreboard(notice: "Match registered") if result.success?

      flash.now[:alert] = result.error
      render new_view, status: :unprocessable_entity
    end

    # Routes the action through the match-type-specific dispatcher,
    # then redirects or re-renders.
    def perform_match_action(action, notice)
      load_match or return
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
      return redirect_to_scoreboard(notice: notice) if result.success?

      render_edit_error(result.error)
    end

    # A failed edit or delete re-renders the edit form (which hosts both
    # actions) with the error; a match that has since vanished sends the
    # player back to the scoreboard instead.
    def render_edit_error(message)
      return unless load_match

      flash.now[:alert] = message
      render :edit, status: :unprocessable_entity
    end

    # Loads the match under edit and records its type for the views; a match
    # that is gone redirects to the scoreboard and answers nil.
    def load_match
      @match = find_match(params[:id])
      return missing_match unless @match

      @multiplayer = @match.is_a?(MultiplayerMatchDetails::Details)
      @match
    end

    def missing_match
      redirect_to_scoreboard(alert: "the match was not found")
      nil
    end

    def redirect_to_scoreboard(**flash_message)
      redirect_to account_league_scoreboard_path(params[:account_id], params[:league_id]), **flash_message
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
      match_scope.merge(user_id: current_user.id,
                        player_ids: params[:player_ids] || [],
                        player_scores: multiplayer_scores_params)
    end

    # Scores arrive as a nested params hash keyed by player id; the commands
    # take a plain string-keyed hash.
    def multiplayer_scores_params
      scores = params.to_unsafe_h[:scores] || {}
      scores.to_h { |k, v| [ k.to_s, v ] }
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
