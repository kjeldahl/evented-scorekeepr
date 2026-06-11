# Facade for the player statistics page: folds the league's matches once,
# replays the stake ledger and assembles points, rank, matches played, form,
# head-to-head and match history in one call, so the controller stays free
# of domain orchestration. Returns nil when the player has not appeared in
# any of the league's matches (they have no standing yet — docs/DOMAIN.md).
module Statistics
  module PlayerPage
    Page = Data.define(:player_id, :name, :points, :rank, :played, :form, :head_to_head, :history)

    extend self

    # league: a LeagueConfig::Config. => a Page, or nil for an unknown player.
    def find(league:, player_id:)
      matches = LeagueMatches.for_league(league.league_id)
      entries = ledger(league).entries(matches)
      points = entries.last&.points || {}
      return nil unless points.key?(player_id)

      names = PlayerNames.for(matches.flat_map(&:players))
      page(player_id, matches, entries, points, names)
    end

    private

    def ledger(league)
      StakeLedger.new(starting_points: league.starting_points, stake_percentage: league.stake_percentage)
    end

    def page(player_id, matches, entries, points, names)
      Page.new(
        player_id:, name: names.fetch(player_id, player_id),
        points: points.fetch(player_id),
        rank: Rankings.rank_of(player_id, points:, names:),
        played: matches.count { |match| match.involves?(player_id) },
        form: Form.tokens(matches, player_id:).join(" "),
        head_to_head: HeadToHead.rows(matches, player_id:, names:),
        history: MatchHistory.rows(entries, player_id:, names:)
      )
    end
  end
end
