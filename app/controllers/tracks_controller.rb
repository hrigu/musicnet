class TracksController < ApplicationController

  def index
    @recently_played_tracks = current_user.spotify_user.recently_played(limit: 50) #=>
  end

  def show
    id = params[:id]
    @track = RSpotify::Track.find ([id]).first
  end
end
