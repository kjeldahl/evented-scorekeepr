# frozen_string_literal: true

namespace :demo do
  desc "Seed demo users, an account, a league and a few matches"
  task seed: :environment do
    seeder = DemoSeeder.new
    seeder.run
    puts seeder.summary
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
end
