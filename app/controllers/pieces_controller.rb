class PiecesController < ApplicationController
  def index


    me = RSpotify::User.find('hrigu')
    @playlists = me.playlists #=> (Playlist array)

  end
end
