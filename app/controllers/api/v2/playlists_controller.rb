class Api::V2::PlaylistsController < Api::V2::ApplicationController
  def index
    playlists = PlaylistResource.all(params)
    respond_with(playlists)
  end

  def show
    playlist = PlaylistResource.find(params)
    respond_with(playlist)
  end

  def create
    playlist = PlaylistResource.build(params)

    if playlist.save
      render jsonapi: playlist, status: 201
    else
      render jsonapi_errors: playlist
    end
  end

  def update
    playlist = PlaylistResource.find(params)

    if playlist.update_attributes
      render jsonapi: playlist
    else
      render jsonapi_errors: playlist
    end
  end

  def destroy
    playlist = PlaylistResource.find(params)

    if playlist.destroy
      render jsonapi: { meta: {} }, status: 200
    else
      render jsonapi_errors: playlist
    end
  end
end
