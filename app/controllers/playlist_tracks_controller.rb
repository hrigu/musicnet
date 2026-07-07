# frozen_string_literal: true

class PlaylistTracksController < ApplicationController
  def create
    playlist = Playlist.find(params[:playlist_id])
    track = Track.find(params[:track_id])
    PlaylistSpotifyWriteService.new(current_user).add_track!(playlist, track)
    redirect_to track_path(track), notice: "Zu \"#{playlist.name}\" hinzugefügt."
  rescue SpotifyPlaylistsGateway::SpotifyWriteError, BuildMusicNetService::SyncAlreadyRunningError => e
    redirect_to track_path(track), alert: e.message
  end

  def destroy
    playlist_track = PlaylistTrack.find(params[:id])
    playlist = playlist_track.playlist
    track = playlist_track.track
    PlaylistSpotifyWriteService.new(current_user).remove_track!(playlist, track)
    redirect_to track_path(track), notice: "Aus \"#{playlist.name}\" entfernt."
  rescue SpotifyPlaylistsGateway::SpotifyWriteError, BuildMusicNetService::SyncAlreadyRunningError => e
    redirect_to track_path(track), alert: e.message
  end
end
