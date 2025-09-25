require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Forkandflame
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Ignore non-Ruby subdirectories in lib
    config.autoload_lib(ignore: %w(assets tasks))

    # Add services and serializers to autoload paths
    config.autoload_paths << Rails.root.join('app/services')
    config.autoload_paths << Rails.root.join('app/serializers')

    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
