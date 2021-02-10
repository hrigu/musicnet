class PlaylistsController < ApplicationController

  def index
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

  def show
    id = params[:id]
    @playlist = RSpotify::Playlist.find_by_id(id)

    tracks = @playlist.tracks()
    tracks_added_at =

    tracks_enhanced = []
    tracks.each do |t|
      tracks_enhanced << {track: t, added_at: @playlist.tracks_added_at[t.id].in_time_zone}
    end

    tracks_enhanced.sort!{|t| t[:added_at]}
    @tracks_enhanced = tracks_enhanced
  end
end
