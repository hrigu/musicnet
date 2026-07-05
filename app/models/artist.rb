# frozen_string_literal: true

class Artist < ApplicationRecord
  # Die Tracks in welchen der Künstler mitwirkt.
  has_and_belongs_to_many :tracks

  # Alle Alben der Tracks in welchen der Künstler mitwirkt
  has_many :albums, -> { distinct }, through: :tracks

  def self.for_index
    preload(:tracks).strict_loading
  end

  def self.for_show(artist)
    artist.tracks.preload(:artists, :album, playlist_tracks: :playlist).strict_loading
  end

  def self.albums_for_show(artist)
    artist.albums.preload(:tracks, :artists).strict_loading
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

  # Reiner Anzeige-Filter (Intent 54, getrennt vom Spotify-Sync) - blank/nil bedeutet "alle
  # Kategorien" (kein Filter). Subquery-Pattern wie Track.by_artist/by_playlist, aus demselben
  # Grund (Join-Fanout vermeiden, unabhaengig von anderen Bedingungen kombinierbar).
  def self.in_active_category(substring)
    return all if substring.blank?

    where(id: joins(tracks: :playlists).where("LOWER(playlists.name) LIKE ?", "%#{substring.downcase}%").select(:id))
  end
end
