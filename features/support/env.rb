# frozen_string_literal: true

require "cucumber/rails"

ActionController::Base.allow_rescue = false

# Scorekeepr has no ActiveRecord: all state lives in the DCB event store.
# Recreate the events table around the suite and wipe it between scenarios
# (the table is append-only, so wiping means drop + recreate).
EventStore.reset!

Before do
  EventStore.reset!
end
