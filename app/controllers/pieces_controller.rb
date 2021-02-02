class PiecesController < ApplicationController

  def index
    #me = RSpotify::User.find('hrigu')
    @me = RSpotify::User.new(JSON.parse(current_user.spotify_user))
    #me = RSpotify::User.new(request.env['omniauth.auth'])

    #me.create_playlist!('supadupa')

    #
    #me.recently_played

    @playlists = @me.recently_played(limit: 50) #=> (Playlist array)

  end
end
