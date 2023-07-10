class PlaylistsController < ApplicationController

  def fetch_all
    BuildMusicNetService.new(current_user).build
  end

  def index
    @playlists = Playlist.all
  end

  def show
    id = params[:id]
    @playlist = Playlist.find(id)
    @tracks = @playlist.playlist_tracks.includes(track: {album: :artists})
    #tracks.sort!{|t| t[:added_at]}
    #@tracks_enhanced = tracks_enhanced
  end

end
