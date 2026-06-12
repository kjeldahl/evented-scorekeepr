# Routes event-store instrumentation through ActiveSupport::Notifications so
# *.dcb events are visible to APM agents, lograge, and any other
# AS::Notifications subscriber. RailsLogSubscriber writes them to the Rails
# logger at debug level in the same format as SQL query logs:
#
#   DCB Append (1.4ms) store=DcbEventStore::Store event_count=2 ...
#   DCB Read   (0.3ms) store=DcbEventStore::Store event_count=5 ...
DcbEventStore.instrumentation = DcbEventStore::ActiveSupportInstrumentation.new
DcbEventStore::RailsLogSubscriber.new.attach_to
