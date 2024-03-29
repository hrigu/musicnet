# frozen_string_literal: true

class TracksController < ApplicationController
  # Zeigt die letzten 50 gespielte Lieder
  # tracks sind RSpotify::Track
  def recently_played_index
    @tracks = current_user.spotify_user.recently_played(limit: 50) #=>
  end

  def index
    @tracks = Track.includes(:artists, :playlists, :album).order(:name)
  end

  def download
    tracks_without_file = []
    Track.all.each do |t|
      path = t.track_path
      tracks_without_file << t unless path
    end

    service = DownloadTrackService.new(tracks_without_file)
    service.download
    redirect_to tracks_path
  end

  def show
    id = params[:id]
    @track = Track.find(id)
    # @spotify_track = RSpotify::Track.find ([@track.spotify_id]).first
  end

  # Spielt den Track in Spotify. Funktioniert leider nicht. Es gibt einen RestClient::Unauthorized (401 Unauthorized)
  # Habe abgerochen. Infos siehe https://www.rubydoc.info/github/guilhermesad/rspotify/master/RSpotify/Player#play_track-instance_method
  def play
    id = params[:id]
    track = Track.find(id)
    uri = "spotify:track:#{track.spotify_id}"
    player = RSpotify::Player.new(current_user.spotify_user)
    player.play_track(nil, uri)
    head :ok
  end

  def stream
    id = params[:id]
    track = Track.find(id)
    track_path = track.track_path
    if track_path
      send_file track_path
    end
    # head :no_content
  end

end
