# frozen_string_literal: true

require "dcb_event_store"
require "connection_pool"
require "pg"

# Application-wide access to the DCB event store. All domain state in
# Scorekeepr lives in the append-only events table; slices read it through
# projections and write through commands that use append conditions for
# consistency.
#
# Two adapters (config/event_store.yml): "postgres" (default) and "memory"
# (DcbEventStore::InMemoryStore — the test default; single-threaded,
# per-process, so parallel test workers are fully isolated).
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
      return block.call(memory_store) if memory?

      pool.with { |conn| block.call(DcbEventStore::Store.new(conn)) }
    end

    def create_schema!
      return if memory?

      pool.with { |conn| DcbEventStore::Schema.create!(conn) }
    end

    def drop_schema!
      return if memory?

      pool.with { |conn| DcbEventStore::Schema.drop!(conn) }
    end

    # Test-only: the events table is append-only, so wiping it means swapping
    # the in-memory store instance, or drop + recreate for PostgreSQL.
    def reset!
      if memory?
        @memory_store = DcbEventStore::InMemoryStore.new
      else
        drop_schema!
        create_schema!
      end
    end

    def memory?
      connection_config[:adapter] == "memory"
    end

    def pool
      @pool ||= ConnectionPool.new(size: pool_size, timeout: 5) { PG.connect(**pg_config) }
    end

    private

    def memory_store
      @memory_store ||= DcbEventStore::InMemoryStore.new
    end

    def pool_size
      Integer(ENV.fetch("EVENT_STORE_POOL_SIZE", 5))
    end

    def connection_config
      Rails.application.config_for(:event_store)
    end

    def pg_config
      config = connection_config
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
