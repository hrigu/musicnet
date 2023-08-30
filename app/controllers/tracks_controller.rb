class TracksController < ApplicationController

  # Zeigt die letzten 50 gespielte Lieder
  # tracks sind RSpotify::Track
  def recently_played_index
    @tracks = current_user.spotify_user.recently_played(limit: 50) #=>
  end

  def index
    @tracks = Track.includes(:artists, :playlists, :album).order(:name)
  end

  def show
    id = params[:id]
    @track = Track.find(id)
    #@spotify_track = RSpotify::Track.find ([@track.spotify_id]).first
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

end
