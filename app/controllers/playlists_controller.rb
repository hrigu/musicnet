# frozen_string_literal: true

class PlaylistsController < ApplicationController
  def fetch_all
    @info = BuildMusicNetService.new(current_user).build
  rescue BuildMusicNetService::SyncAlreadyRunningError => e
    redirect_to playlists_path, alert: e.message
  end

  def index
    # Track-Anzahl direkt mitzählen statt einer COUNT-Query pro Zeile im Partial
    @playlists = Playlist.left_joins(:playlist_tracks)
                         .select("playlists.*", "COUNT(playlist_tracks.id) AS tracks_count")
                         .group("playlists.id")
                         .order(:name)
  end

  def show
    id = params[:id]
    @playlist = Playlist.find(id)
    @playlist_tracks = playlist_tracks_with_associations
  end

  # Gleicht die Playlist mit Spotify ab und zeigt sie mit den Änderungen an
  def refresh
    @playlist = Playlist.find(params[:id])
    @refresh_info = BuildMusicNetService.new(current_user).refresh_playlist(@playlist)
    @playlist_tracks = playlist_tracks_with_associations
    render :show
  rescue BuildMusicNetService::PlaylistNotFoundError, BuildMusicNetService::SyncAlreadyRunningError => e
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
  rescue DownloadPlaylistService::DownloadAlreadyRunningError => e
    redirect_to playlist_path(id), alert: e.message
  end

  private

  # Lädt alles vor, was das _playlist_track-Partial anzeigt (vermeidet N+1-Queries)
  def playlist_tracks_with_associations
    @playlist.playlist_tracks.includes(track: [:artists, :album, { playlist_tracks: :playlist }])
  end
end
