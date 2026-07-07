# frozen_string_literal: true

class Playlist < ApplicationRecord
  # dependent: :destroy, damit beim Löschen einer entfolgten Playlist (Sync) die
  # Zuordnungen mitgehen — die Tracks selbst räumt der Orphan-Cleanup des Syncs ab.
  has_many :playlist_tracks, dependent: :destroy
  has_many :tracks, through: :playlist_tracks
  has_many :library_playlists, dependent: :destroy
  has_many :libraries, through: :library_playlists

  scope :for_index, -> { order(:name).strict_loading }

  # Reiner Anzeige-Filter (Intent 57, ersetzt in_active_category aus Intent 54), getrennt vom
  # Spotify-Sync - blank/nil bedeutet "Alle" (kein Filter).
  def self.in_active_library(library_id)
    return all if library_id.blank?

    where(id: joins(:libraries).where(libraries: { id: library_id }).select(:id))
  end

  def name_path_ready
    name.delete(' ')
  end

  def playlist_tracks_for_display
    playlist_tracks.preload(track: [:artists, :album, { playlist_tracks: :playlist }, { track_tags: { tag: :category } }]).strict_loading.tap do |records|
      Track.preload_track_paths(records.map(&:track))
    end
  end

  # Tracks dieser Playlist ohne lokale Audiodatei (siehe Track#track_path).
  def missing_tracks
    all_tracks = tracks.to_a
    Track.preload_track_paths(all_tracks)
    all_tracks.reject(&:track_path)
  end
end
