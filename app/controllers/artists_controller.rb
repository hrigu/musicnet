# frozen_string_literal: true

class ArtistsController < ApplicationController
  def index
    @artists = Artist.for_index.in_active_library(current_user.active_library_id)
    @playlists_by_artist_id = Artist.playlists_by_artist_id
  end

  def show
    @artist = Artist.find(params[:id])
    @tracks = Artist.for_show(@artist).sorted(params[:sort], params[:direction])
    Track.preload_track_paths(@tracks)
    @albums = Artist.albums_for_show(@artist)
  end
end
