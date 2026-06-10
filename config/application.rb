require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
# require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Scorekeepr
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Vertical slices: each directory under app/slices is a self-contained
    # feature slice namespaced by its directory name (Identity, Leagues, ...).
    # The domain/ and web/ subdirectories are collapsed so they organise files
    # without adding namespace depth: app/slices/leagues/domain/create_league.rb
    # defines Leagues::CreateLeague.
    slices_root = root.join("app/slices")
    config.autoload_paths << slices_root
    config.eager_load_paths << slices_root
    initializer "scorekeepr.collapse_slice_dirs", before: :setup_main_autoloader do
      Rails.autoloaders.main.collapse(slices_root.join("*/domain"))
      Rails.autoloaders.main.collapse(slices_root.join("*/web"))
    end
    config.paths["app/views"].concat(Dir[slices_root.join("*/views")])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
