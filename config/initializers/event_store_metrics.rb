# Production-only: event store metrics to AppSignal (dcb.<operation>.duration,
# dcb.append.events, dcb.append.conflicts, ...; tagged store/namespace only,
# no event data). The gem's Railtie has already routed *.dcb events through
# ActiveSupport::Notifications and attached the debug log subscriber.
if Rails.env.production?
  DcbEventStore::AppsignalSubscriber.new.attach_to
end
