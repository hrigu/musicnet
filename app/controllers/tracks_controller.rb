# frozen_string_literal: true

class TracksController < ApplicationController
  PAGE_SIZE = 50

  # Zeigt die letzten 50 gespielte Lieder
  # tracks sind RSpotify::Track
  def recently_played_index
    @tracks = current_user.spotify_user.recently_played(limit: 50) #=>
  end

  def index
    tracks = Track.for_index.search(params[:q]).sorted(params[:sort], params[:direction])
    @pagy, @tracks = pagy(:offset, tracks, limit: PAGE_SIZE)
    Track.preload_track_paths(@tracks)
  end

  def download
    tracks_without_file = Track.for_download.reject(&:track_path)

    service = DownloadTrackService.new(tracks_without_file)
    service.download
    redirect_to tracks_path
  rescue DownloadPlaylistService::DownloadAlreadyRunningError => e
    redirect_to tracks_path, alert: e.message
  end

  def show
    @track = Track.for_show.find(params[:id])
  end

  def stream
    track = Track.find(params[:id])
    track_path = track.track_path
    send_file track_path if track_path
  end
end
