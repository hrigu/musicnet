# frozen_string_literal: true

class Api::V1::PlaylistsController < Api::V1::BaseController

  def index
    @playlists = Playlist.order(:name)
    render json: @playlists
  end
end