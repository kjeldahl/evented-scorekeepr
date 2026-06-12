# The websocket endpoint is mounted explicitly at /cable in config/routes.rb
# (the engine's automatic mount is disabled in config/application.rb), so the
# client-side URL advertised by action_cable_meta_tag is configured here.
# A relative path: the ActionCable JS client resolves it against the page's
# host, switching to ws(s):// as appropriate.
Rails.application.config.action_cable.url = "/cable"
