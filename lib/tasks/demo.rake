# frozen_string_literal: true

namespace :demo do
  desc "Seed demo users, an account, a league and a few matches"
  task seed: :environment do
    seeder = DemoSeeder.new
    seeder.run
    puts seeder.summary
  end

  desc "Populate an account (ACCOUNT=Clubhouse) with 2 leagues and 10 players; MATCHES=n adds n random matches per league"
  task populate: :environment do
    populator = DemoPopulator.new(
      account_name: ENV.fetch("ACCOUNT", "Clubhouse"),
      matches_per_league: Integer(ENV.fetch("MATCHES", "0"))
    )
    populator.run
    puts populator.summary
  end

  # Drives the real domain commands so every invariant holds; safe to run
  # repeatedly (re-runs fail the duplicate-email guard and are reported).
  class DemoSeeder
    PASSWORD = "secret123"
    PLAYERS = %w[Alice Bob Carol Dave].freeze
    MATCHES = [
      { home: %w[Alice], away: %w[Bob], score: [ 21, 8 ] },
      { home: %w[Bob], away: %w[Alice], score: [ 21, 19 ] },
      { home: %w[Alice Carol], away: %w[Bob Dave], score: [ 10, 4 ] },
      { home: %w[Dave], away: %w[Carol], score: [ 21, 15 ] }
    ].freeze

    def run
      register_players
      return unless @user_ids

      create_account
      invite_members
      create_league
      register_matches
    end

    def summary
      return "Demo data already present (alice@example.com is registered) - nothing seeded." unless @user_ids

      "Seeded #{PLAYERS.join(', ')} (password '#{PASSWORD}'), account 'Office', " \
        "league 'Foosball Spring' with #{MATCHES.size} matches."
    end

    private

    def register_players
      results = PLAYERS.to_h do |name|
        [ name, Identity::RegisterUser.call(name: name, email: email_for(name), password: PASSWORD) ]
      end
      return if results.values.any?(&:failure?)

      @user_ids = results.transform_values(&:value)
    end

    def email_for(name) = "#{name.downcase}@example.com"

    def create_account
      @account_id = Accounts::CreateAccount.call(name: "Office", owner_user_id: @user_ids.fetch("Alice")).value
    end

    def invite_members
      PLAYERS.drop(1).each do |name|
        invitation_id = Accounts::InvitePlayer.call(
          account_id: @account_id, email: email_for(name), invited_by_user_id: @user_ids.fetch("Alice")
        ).value
        Accounts::AcceptInvitation.call(
          invitation_id: invitation_id, user_id: @user_ids.fetch(name), user_email: email_for(name)
        )
      end
    end

    def create_league
      @league_id = Leagues::CreateLeague.call(
        account_id: @account_id, user_id: @user_ids.fetch("Alice"),
        name: "Foosball Spring", game_type: "Foosball"
      ).value
    end

    def register_matches
      MATCHES.each do |match|
        Matches::RegisterMatch.call(
          league_id: @league_id, account_id: @account_id, user_id: @user_ids.fetch("Alice"),
          home_player_ids: match[:home].map { |n| @user_ids.fetch(n) },
          away_player_ids: match[:away].map { |n| @user_ids.fetch(n) },
          home_score: match[:score][0], away_score: match[:score][1]
        )
      end
    end
  end

  # Populates a fresh account with 2 leagues and 10 players (plus one extra
  # registered player left with a pending invitation — handy for the account
  # page's outgoing invitations list and the development accept-on-behalf
  # button). Drives the real domain commands so every invariant holds.
  # Player emails are derived from the account name, so each distinct
  # ACCOUNT=... run seeds an independent data set; re-running for the same
  # account fails the duplicate-email guard and reports that nothing was done.
  class DemoPopulator
    PASSWORD = "secret123"
    PLAYERS = %w[Erin Frank Grace Heidi Ivan Judy Karl Lena Mike Nora].freeze
    PENDING_PLAYER = "Pat"
    LEAGUES = [
      { name: "Foosball", game_type: "Foosball" },
      { name: "Table Tennis", game_type: "Table Tennis" }
    ].freeze

    def initialize(account_name:, matches_per_league:)
      @account_name = account_name
      @matches_per_league = matches_per_league
    end

    def run
      register_players
      return unless @user_ids

      create_account
      add_members
      invite(PENDING_PLAYER)
      create_leagues
      register_matches
    end

    def summary
      return "Account '#{@account_name}' is already populated (#{email_for(PLAYERS.first)} is registered) - nothing seeded." unless @user_ids

      "Populated account '#{@account_name}' with #{PLAYERS.size} players (#{PLAYERS.join(', ')}, password '#{PASSWORD}'), " \
        "#{LEAGUES.size} leagues (#{LEAGUES.map { |league| league[:name] }.join(', ')}), " \
        "#{@matches_per_league} random matches per league and a pending invitation for #{email_for(PENDING_PLAYER)}."
    end

    private

    def email_for(name) = "#{name.downcase}@#{account_slug}.example.com"

    def account_slug = @account_name.downcase.gsub(/[^a-z0-9]+/, "-")

    def owner_id = @user_ids.fetch(PLAYERS.first)

    def register_players
      results = (PLAYERS + [ PENDING_PLAYER ]).to_h do |name|
        [ name, Identity::RegisterUser.call(name:, email: email_for(name), password: PASSWORD) ]
      end
      return if results.values.any?(&:failure?)

      @user_ids = results.transform_values(&:value)
    end

    def create_account
      @account_id = Accounts::CreateAccount.call(name: @account_name, owner_user_id: owner_id).value
    end

    def add_members
      PLAYERS.drop(1).each do |name|
        invitation_id = invite(name)
        Accounts::AcceptInvitation.call(invitation_id:, user_id: @user_ids.fetch(name), user_email: email_for(name))
      end
    end

    def invite(name)
      Accounts::InvitePlayer.call(account_id: @account_id, email: email_for(name), invited_by_user_id: owner_id).value
    end

    def create_leagues
      @league_ids = LEAGUES.map do |league|
        Leagues::CreateLeague.call(account_id: @account_id, user_id: owner_id,
                                   name: league[:name], game_type: league[:game_type]).value
      end
    end

    def register_matches
      @league_ids.each do |league_id|
        @matches_per_league.times { register_random_match(league_id) }
      end
    end

    def register_random_match(league_id)
      home, away = random_sides
      home_score, away_score = random_scores
      Matches::RegisterMatch.call(
        league_id:, account_id: @account_id, user_id: owner_id,
        home_player_ids: home, away_player_ids: away, home_score:, away_score:
      )
    end

    # 1v1 or 2v2 with distinct members; 21 against a random lower score, so
    # there is always a winner and never a draw.
    def random_sides
      players = @user_ids.values_at(*PLAYERS).shuffle
      side_size = [ 1, 2 ].sample
      [ players.first(side_size), players.last(side_size) ]
    end

    def random_scores = [ 21, rand(0..19) ].shuffle
  end
end
