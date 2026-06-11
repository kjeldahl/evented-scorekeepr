# frozen_string_literal: true

require "cucumber/rails"

ActionController::Base.allow_rescue = false

# Skip BCrypt key stretching in tests (~0.25s per hash at the default cost).
BCrypt::Engine.cost = BCrypt::Engine::MIN_COST

# Scorekeepr has no ActiveRecord: all state lives in the DCB event store.
# Wipe it around the suite and between scenarios (fresh in-memory store by
# default; drop + recreate when EVENT_STORE_ADAPTER=postgres).
EventStore.reset!

Before do
  EventStore.reset!
end
