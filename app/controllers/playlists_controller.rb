# frozen_string_literal: true

class PlaylistsController < ApplicationController
  def fetch_all
    @info = BuildMusicNetService.new(current_user).build
  end

  def index
    @playlists = Playlist.order(:name)
  end

  def show
    id = params[:id]
    @playlist = Playlist.find(id)
    @playlist_tracks = @playlist.playlist_tracks.includes(track: { album: :artists })
  end

  def download
    id = params[:id]
    @playlist = Playlist.find(id)
    service = DownloadPlaylistService.new(current_user, @playlist)
    service.download
    @playlists = Playlist.includes(playlist_tracks: :track).all

    render :index
  end
end
