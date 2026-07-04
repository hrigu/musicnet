# frozen_string_literal: true

class Playlist < ApplicationRecord
  # dependent: :destroy, damit beim Löschen einer entfolgten Playlist (Sync) die
  # Zuordnungen mitgehen — die Tracks selbst räumt der Orphan-Cleanup des Syncs ab.
  has_many :playlist_tracks, dependent: :destroy
  has_many :tracks, through: :playlist_tracks

  scope :for_index, -> { order(:name).strict_loading }

  def name_path_ready
    name.delete(' ')
  end

  def playlist_tracks_for_display
    playlist_tracks.preload(track: [:artists, :album, { playlist_tracks: :playlist }]).strict_loading.tap do |records|
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
