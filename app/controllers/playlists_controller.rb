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

  # Lädt alle Tracks der Plylist runter und zeigt dann diese Plylit an
  def download
    id = params[:id]
    @playlist = Playlist.find(id)
    service = DownloadPlaylistService.new(current_user, @playlist)
    service.download
    redirect_to playlist_path(id)
  end
end
