# frozen_string_literal: true

class Artist < ApplicationRecord
  # Die Tracks in welchen der Künstler mitwirkt.
  has_and_belongs_to_many :tracks

  # Alle Alben der Tracks in welchen der Künstler mitwirkt
  has_many :albums, -> { distinct }, through: :tracks

  def self.for_index
    includes(:tracks).strict_loading
  end

  def self.for_show(artist)
    artist.tracks.includes(:artists, :album, playlist_tracks: :playlist).strict_loading
  end

  def self.albums_for_show(artist)
    artist.albums.includes(:tracks, :artists).strict_loading
  end

  # Die Playlists aller Künstler auf einmal, gruppiert nach Künstler-ID — eine Query für
  # die ganze Index-Seite statt einer pro Zeile (siehe #playlists_of_the_tracks für den
  # Einzel-Fall).
  def self.playlists_by_artist_id
    Playlist.distinct
            .joins(playlist_tracks: { track: :artists })
            .select("playlists.*", "artists.id AS artist_id")
            .group_by(&:artist_id)
  end

  def playlists_of_the_tracks
    Playlist.distinct.joins(playlist_tracks: { track: :artists }).where(artists: { id: id })
  end
end
