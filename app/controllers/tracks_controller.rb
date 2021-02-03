class TracksController < ApplicationController

  def recently_played

    @recently_played_tracks = current_user.spotify_user.recently_played(limit: 50) #=>

  end
end
