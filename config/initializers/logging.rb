# Send logs to AppSignal, but keep broadcasting to STDOUT (config.logger in
# config/environments/production.rb) so `kamal logs` still works.
if Rails.env.production?
  require "appsignal"
  appsignal_logger = Appsignal::Logger.new("rails")
  appsignal_logger.broadcast_to(Rails.logger)
  Rails.logger = ActiveSupport::TaggedLogging.new(appsignal_logger)
end