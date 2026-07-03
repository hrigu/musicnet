# frozen_string_literal: true

class PlaylistsController < ApplicationController
  def fetch_all
    @info = BuildMusicNetService.new(current_user).build
  rescue BuildMusicNetService::SyncAlreadyRunningError => e
    redirect_to playlists_path, alert: e.message
  end

  def index
    @playlists = Playlist.for_index
  end

  def show
    @playlist = Playlist.find(params[:id])
    @playlist_tracks = @playlist.playlist_tracks_for_display
  end

  # Gleicht die Playlist mit Spotify ab und zeigt sie mit den Änderungen an
  def refresh
    @playlist = Playlist.find(params[:id])
    @refresh_info = BuildMusicNetService.new(current_user).refresh_playlist(@playlist)
    @playlist_tracks = @playlist.playlist_tracks_for_display
    render :show
  rescue BuildMusicNetService::PlaylistNotFoundError, BuildMusicNetService::SyncAlreadyRunningError => e
    redirect_to playlist_path(@playlist), alert: e.message
  end

  def edit
    @playlist = Playlist.find(params[:id])
  end

  def update
    @playlist = Playlist.find(params[:id])
    @playlist.save!
    redirect_to playlists_path
  end

  # Lädt alle Tracks der Plylist runter und zeigt dann diese Plylit an
  def download
    @playlist = Playlist.find(params[:id])
    service = DownloadPlaylistService.new(@playlist)
    service.download
    redirect_to playlist_path(@playlist)
  rescue DownloadPlaylistService::DownloadAlreadyRunningError => e
    redirect_to playlist_path(@playlist), alert: e.message
  end
end
