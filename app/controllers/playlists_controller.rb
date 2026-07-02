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

  # Gleicht die Playlist mit Spotify ab und zeigt sie mit den Änderungen an
  def refresh
    @playlist = Playlist.find(params[:id])
    @refresh_info = BuildMusicNetService.new(current_user).refresh_playlist(@playlist)
    @playlist_tracks = @playlist.playlist_tracks.includes(track: { album: :artists })
    render :show
  rescue BuildMusicNetService::PlaylistNotFoundError => e
    redirect_to playlist_path(@playlist), alert: e.message
  end

  def edit
    id = params[:id]
    @playlist = Playlist.find(id)
  end

  def update
    id = params[:id]
    @playlist = Playlist.find(id)
    @playlist.save!
    redirect_to playlists_path
  end

  # Lädt alle Tracks der Plylist runter und zeigt dann diese Plylit an
  def download
    id = params[:id]
    @playlist = Playlist.find(id)
    service = DownloadPlaylistService.new(@playlist)
    service.download
    redirect_to playlist_path(id)
  end
end
