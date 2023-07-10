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
    @playlist_tracks = @playlist.playlist_tracks.includes(track: { album: :artists})
  end

  def download
    id = params[:id]
    @playlist = Playlist.find(id)
    service = DownloadPlaylistService.new(current_user, @playlist)
    service.download
    @playlists = Playlist.all

    render :index
  end

end
