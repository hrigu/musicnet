class PiecesController < ApplicationController
  def index
    client_id = Rails.application.credentials.dig(:spotify, :client_id)
    client_secret = Rails.application.credentials.dig(:spotify, :client_secret)
    Rails.logger.info "client_id: #{client_id}"

    RSpotify.authenticate(client_id, client_secret)

    me = RSpotify::User.find('hrigu')
    @playlists = me.playlists #=> (Playlist array)

  end
end
