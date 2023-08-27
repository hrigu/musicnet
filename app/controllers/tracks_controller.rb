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
end
