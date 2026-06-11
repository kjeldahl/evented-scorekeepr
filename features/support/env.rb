# frozen_string_literal: true

require "cucumber/rails"

ActionController::Base.allow_rescue = false

# Scorekeepr has no ActiveRecord: all state lives in the DCB event store.
# Wipe it around the suite and between scenarios (fresh in-memory store by
# default; drop + recreate when EVENT_STORE_ADAPTER=postgres).
EventStore.reset!

Before do
  EventStore.reset!
end
