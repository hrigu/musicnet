
# config/initializers/omniauth.rb

# require 'rspotify/oauth'
#
# Rails.application.config.middleware.use OmniAuth::Builder do
#   Rails.logger.info "Ominiaout: Use Spotify"
#   client_id = Rails.application.credentials.dig(:spotify, :client_id)
#   client_secret = Rails.application.credentials.dig(:spotify, :client_secret)
#
#   provider :spotify, client_id, client_secret#, scope: 'user-read-email playlist-modify-public user-library-read user-library-modify'
# end