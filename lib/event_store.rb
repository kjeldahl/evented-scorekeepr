# frozen_string_literal: true

require "dcb_event_store"
require "connection_pool"
require "pg"

# Application-wide access to the DCB event store. All domain state in
# Scorekeepr lives in the append-only events table; slices read it through
# projections and write through commands that use append conditions for
# consistency.
module EventStore
  class << self
    def append(events, condition = nil)
      with_store { |store| store.append(events, condition) }
    end

    def read(query)
      with_store { |store| store.read(query).to_a }
    end

    # Builds a decision model from one or more named projections, yielding
    # their folded states and an append condition covering everything read.
    def decide(**projections)
      with_store { |store| DcbEventStore::DecisionModel.build(store, **projections) }
    end

    def project(projection)
      decide(state: projection).states[:state]
    end

    def with_store(&block)
      pool.with { |conn| block.call(DcbEventStore::Store.new(conn)) }
    end

    def create_schema!
      pool.with { |conn| DcbEventStore::Schema.create!(conn) }
    end

    def drop_schema!
      pool.with { |conn| DcbEventStore::Schema.drop!(conn) }
    end

    # Test-only: the events table is append-only, so wiping it requires
    # dropping and recreating the schema rather than TRUNCATE/DELETE.
    def reset!
      drop_schema!
      create_schema!
    end

    def pool
      @pool ||= ConnectionPool.new(size: pool_size, timeout: 5) { PG.connect(**connection_config) }
    end

    private

    def pool_size
      Integer(ENV.fetch("EVENT_STORE_POOL_SIZE", 5))
    end

    def connection_config
      config = Rails.application.config_for(:event_store)
      {
        host: config[:host],
        port: config[:port],
        dbname: config[:database],
        user: config[:username],
        password: config[:password]
      }.compact
    end
  end
end
