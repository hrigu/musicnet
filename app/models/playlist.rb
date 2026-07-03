# frozen_string_literal: true

class Playlist < ApplicationRecord
  # dependent: :destroy, damit beim Löschen einer entfolgten Playlist (Sync) die
  # Zuordnungen mitgehen — die Tracks selbst räumt der Orphan-Cleanup des Syncs ab.
  has_many :playlist_tracks, dependent: :destroy
  has_many :tracks, through: :playlist_tracks

  def self.for_index
    left_joins(:playlist_tracks)
      .select("playlists.*", "COUNT(playlist_tracks.id) AS tracks_count")
      .group("playlists.id")
      .order(:name)
  end

  def name_path_ready
    name.delete(' ')
  end

  # Der Playlist-Index lädt die Anzahl als SELECT-Alias gebündelt mit (eine Query für alle
  # Playlists); überall sonst, z.B. auf der Track-Detailseite, wird pro Playlist gezählt.
  def tracks_count
    self[:tracks_count] || tracks.count
  end

  def playlist_tracks_for_display
    playlist_tracks.includes(track: [:artists, :album, { playlist_tracks: :playlist }]).tap do |records|
      Track.preload_track_paths(records.map(&:track))
    end
  end

  private

  def calculate_checksum(str)
    checksum = 0
    str.each_byte do |byte|
      checksum += byte
    end
    checksum
  end

end
