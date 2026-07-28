# The matches slice's event constructors. Only this module builds the
# events the slice owns, and only this slice appends them (docs/DOMAIN.md).
# A MatchRegistered event is tagged with the match, league and account plus
# one player tag per participant, so scoreboards can fold per-player.
module Matches
  module Events
    extend self

    def match_registered(match_id:, league_id:, account_id:, home_player_ids:, away_player_ids:,
                         home_score:, away_score:, registered_by_user_id:)
      DcbEventStore::Event.new(
        type: "MatchRegistered",
        data: { match_id:, league_id:, account_id:, home_player_ids:, away_player_ids:,
                home_score:, away_score:, registered_by_user_id: },
        tags: [ "match:#{match_id}", "league:#{league_id}", "account:#{account_id}",
                *(home_player_ids + away_player_ids).map { |player_id| "player:#{player_id}" } ]
      )
    end

    # A correction changes only the score; the sides are fixed, so the event
    # carries no player ids and is tagged with the match, league and account
    # (docs/DOMAIN.md). Scoreboards and statistics fold it onto the matching
    # MatchRegistered and re-derive every later standing.
    def match_result_corrected(match_id:, league_id:, account_id:, home_score:, away_score:,
                               corrected_by_user_id:)
      DcbEventStore::Event.new(
        type: "MatchResultCorrected",
        data: { match_id:, league_id:, account_id:, home_score:, away_score:, corrected_by_user_id: },
        tags: [ "match:#{match_id}", "league:#{league_id}", "account:#{account_id}" ]
      )
    end

    # A deletion removes the match from the league as if it never happened; it
    # carries no score or sides and is tagged with the match, league and
    # account (docs/DOMAIN.md). Scoreboards and statistics drop the matching
    # match and re-derive every later standing; MatchDetails folds it to gone,
    # so the match can no longer be deleted or edited.
    def match_deleted(match_id:, league_id:, account_id:, deleted_by_user_id:)
      DcbEventStore::Event.new(
        type: "MatchDeleted",
        data: { match_id:, league_id:, account_id:, deleted_by_user_id: },
        tags: [ "match:#{match_id}", "league:#{league_id}", "account:#{account_id}" ]
      )
    end

    # A multiplayer match result is registered: each player enters a score
    # (integer, can be negative). Tagged with the match, league, account and
    # one player tag per participant (docs/DOMAIN.md).
    def multiplayer_match_registered(match_id:, league_id:, account_id:, player_ids:, player_scores:,
                                     registered_by_user_id:)
      DcbEventStore::Event.new(
        type: "MultiplayerMatchRegistered",
        data: { match_id:, league_id:, account_id:, player_ids:, player_scores:, registered_by_user_id: },
        tags: [ "match:#{match_id}", "league:#{league_id}", "account:#{account_id}",
                *player_ids.map { |player_id| "player:#{player_id}" } ]
      )
    end

    # A correction changes only the scores; the participants are fixed, so the
    # event carries no player ids and is tagged with the match, league and
    # account (docs/DOMAIN.md).
    def multiplayer_match_result_corrected(match_id:, league_id:, account_id:, player_scores:,
                                           corrected_by_user_id:)
      DcbEventStore::Event.new(
        type: "MultiplayerMatchResultCorrected",
        data: { match_id:, league_id:, account_id:, player_scores:, corrected_by_user_id: },
        tags: [ "match:#{match_id}", "league:#{league_id}", "account:#{account_id}" ]
      )
    end

    # A deletion removes the multiplayer match from the league as if it never
    # happened; tagged with the match, league and account (docs/DOMAIN.md).
    def multiplayer_match_deleted(match_id:, league_id:, account_id:, deleted_by_user_id:)
      DcbEventStore::Event.new(
        type: "MultiplayerMatchDeleted",
        data: { match_id:, league_id:, account_id:, deleted_by_user_id: },
        tags: [ "match:#{match_id}", "league:#{league_id}", "account:#{account_id}" ]
      )
    end
  end
end
