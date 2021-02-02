class TracksController < ApplicationController

  def recently_played
    #me = RSpotify::User.find('hrigu')
    @me = RSpotify::User.new(JSON.parse(current_user.spotify_user))
    #me = RSpotify::User.new(request.env['omniauth.auth'])

    #me.create_playlist!('supadupa')

    #
    #me.recently_played

    # Maximale Anzahl ist 50. Dann kommt ne Fehlermeldung
    # Ist ein Array von Tracks
    @recently_played_tracks = @me.recently_played(limit: 50) #=>

  end
end
