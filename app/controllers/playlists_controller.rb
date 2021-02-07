class PlaylistsController < ApplicationController

  def my_playlists

    @playlists = []
    offset = 0
    limit = 50
    loop do
      playlists = current_user.spotify_user.playlists(limit: limit, offset: offset) #=>
      break if playlists.empty?
      @playlists << playlists
      offset+=limit
    end
    @playlists.flatten!
  end
end
