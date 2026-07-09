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
    # tracks/_tracks.erb (ueber tracks/_track.erb -> _tag_cell.erb -> _tag_assign_inline.erb)
    # braucht @recent_tag_suggestions, obwohl diese Seite kein TracksController-Request ist - siehe
    # gleicher Aufruf in TracksController#index/#show.
    @recent_tag_suggestions = Tag.recently_assigned_by(current_user, limit: TracksController::RECENT_TAG_SUGGESTION_LIMIT)
  end
end
