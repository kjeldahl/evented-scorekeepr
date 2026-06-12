# Facade for the player statistics page: folds the league's matches once,
# replays the stake ledger and assembles points, rank, matches played, form,
# head-to-head and match history in one call, so the controller stays free
# of domain orchestration. Returns nil when the player has not appeared in
# any of the league's matches (they have no standing yet — docs/DOMAIN.md).
module Statistics
  module PlayerPage
    Page = Data.define(:player_id, :name, :points, :rank, :played, :form, :head_to_head,
                       :history, :history_page, :history_pages)

    extend self

    # league: a LeagueConfig::Config. => a Page, or nil for an unknown player.
    # history_page selects the match-history page (clamped into range).
    def find(league:, player_id:, history_page: 1)
      matches = LeagueMatches.for_league(league.league_id)
      entries = ledger(league).entries(matches)
      points = entries.last&.points || {}
      return nil unless points.key?(player_id)

      names = PlayerNames.for(matches.flat_map(&:players))
      page(player_id, matches, entries, points, names, history_page)
    end

    private

    def ledger(league)
      StakeLedger.new(starting_points: league.starting_points, stake_percentage: league.stake_percentage)
    end

    def page(player_id, matches, entries, points, names, history_page)
      history = MatchHistory.page(entries, player_id:, names:, number: history_page)
      Page.new(
        player_id:, name: names.fetch(player_id, player_id),
        points: points.fetch(player_id),
        rank: Rankings.rank_of(player_id, points:, names:),
        played: matches.count { |match| match.involves?(player_id) },
        form: Form.tokens(matches, player_id:).join(" "),
        head_to_head: HeadToHead.rows(matches, player_id:, names:),
        history: history.rows, history_page: history.number, history_pages: history.pages
      )
    end
  end
end
