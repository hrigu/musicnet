require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Musicnet
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    config.autoload_paths += %W(#{Rails.root}/services)

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Bern"

    # config.eager_load_paths << Rails.root.join("extras")
    #
    client_id = Rails.application.credentials.dig(:spotify, :client_id)
    client_secret = Rails.application.credentials.dig(:spotify, :client_secret)
    RSpotify.authenticate(client_id, client_secret)

  end
end
