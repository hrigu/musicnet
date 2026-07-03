# frozen_string_literal: true

class ArtistsController < ApplicationController
  def index
    # :albums wird vom Partial nicht verwendet — nur :tracks (für die Anzahl) vorladen
    @artists = Artist.includes(:tracks).all
    @playlists_by_artist_id = Artist.playlists_by_artist_id
  end

  def show
    id = params[:id]
    @artist = Artist.find(id)
    @tracks = @artist.tracks.includes(:artists, :album, playlist_tracks: :playlist)
    Track.preload_track_paths(@tracks)
    @albums = @artist.albums.includes(:tracks, :artists)
  end
end
