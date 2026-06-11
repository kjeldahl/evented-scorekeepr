# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

# Skip BCrypt key stretching in tests (~0.25s per hash at the default cost).
BCrypt::Engine.cost = BCrypt::Engine::MIN_COST

RSpec.configure do |config|
  config.use_active_record = false

  # All state lives in the DCB event store; wipe it between examples that
  # touch it (fresh in-memory store, or drop + recreate under postgres).
  config.before(:suite) { EventStore.reset! }
  config.before(:each, :event_store) { EventStore.reset! }

  config.filter_rails_from_backtrace!
end
