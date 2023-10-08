require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Musicnet
  class Application < Rails::Application

    def authenticate_to_spotify
      puts "authenticat_to_spotify"
      # Die App als "spoty" authentisieren
      client_id = Rails.application.credentials.dig(:spotify, :client_id)
      client_secret = Rails.application.credentials.dig(:spotify, :client_secret)
      result = RSpotify.authenticate(client_id, client_secret)
      puts( result ? "...erfolgreich": "...nicht geklappt")
    end

    # # In order for Graphiti to generate links, you need to set the routes host.
    # # When not explicitly set, via the HOST env var, this will fall back to
    # # the rails server settings.
    # # Rails::Server is not defined in console or rake tasks, so this will only
    # # use those defaults when they are available.
    # routes.default_url_options[:host] = ENV.fetch('HOST') do
    #   if defined?(Rails::Server)
    #     argv_options = Rails::Server::Options.new.parse!(ARGV)
    #     "http://#{argv_options[:Host]}:#{argv_options[:Port]}"
    #   end
    # end

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

  end
end
