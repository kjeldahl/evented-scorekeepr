# Bridges the event store to ActionCable (docs/ARCHITECTURE.md § Live
# updates): after every successful append, broadcast `{ type: event.type }`
# on the stream "events:{tag}" for every tag of every appended event. The
# broadcast is infrastructure, not an event — nothing is appended, no new
# event types exist. Slice channels (e.g. Scoreboards::TvChannel) subscribe
# clients to these tag streams.
#
# to_prepare: in development the reloadable EventStore module is replaced on
# every code reload, dropping its hooks — re-register on the fresh module.
# In test/production this runs exactly once at boot.
Rails.application.config.to_prepare do
  EventStore.on_append do |events|
    events.each do |event|
      event.tags.each do |tag|
        ActionCable.server.broadcast("events:#{tag}", { type: event.type })
      rescue StandardError
        nil # fire-and-forget: a failed broadcast never fails the append path
      end
    end
  end
end
