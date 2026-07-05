# frozen_string_literal: true

class ArtistsController < ApplicationController
  def index
    @artists = Artist.for_index.in_active_category(current_user.active_category_substring)
    @playlists_by_artist_id = Artist.playlists_by_artist_id
  end

  def show
    @artist = Artist.find(params[:id])
    @tracks = Artist.for_show(@artist)
    Track.preload_track_paths(@tracks)
    @albums = Artist.albums_for_show(@artist)
  end
end
