# frozen_string_literal: true

class Playlist < ApplicationRecord
  # dependent: :destroy, damit beim Löschen einer entfolgten Playlist (Sync) die
  # Zuordnungen mitgehen — die Tracks selbst räumt der Orphan-Cleanup des Syncs ab.
  has_many :playlist_tracks, dependent: :destroy
  has_many :tracks, through: :playlist_tracks

  COLORS = %i[green blue yellow red lila orange black brown].freeze
  CONTEXT = [
    'bg-primary',
    'bg-secondary',
    'bg-success',
    'bg-danger',
    'bg-warning',
    'bg-info',
    "bg-light",
  ].freeze

  def color_class
    select_color short_name
  end

  # Um die Groß- und Kleinschreibung zu ignorieren, nutzen wir einen regulären Ausdruck mit dem i-Flag.
  def short_name
    name.gsub(/\bfusion\b/i, '_F_') # \b Wortgrenze
       .gsub(/\bblues\b/i, '_B_')
      .gsub(/\s+/, '')
      .gsub(/_+/, '_')
      .gsub(/\A_+/, '')
      .gsub(/_+\z/, '')

  end

  def name_path_ready
    name.delete(' ')
  end

  # Der Playlist-Index lädt die Anzahl als SELECT-Alias gebündelt mit (eine Query für alle
  # Playlists); überall sonst, z.B. auf der Track-Detailseite, wird pro Playlist gezählt.
  def tracks_count
    self[:tracks_count] || tracks.count
  end

  private

  def calculate_checksum(str)
    checksum = 0
    str.each_byte do |byte|
      checksum += byte
    end
    checksum
  end

  def select_color(str)
    if is_a_dj_playlist? str
      'bg-dark'
    else
      checksum = calculate_checksum(str)
      CONTEXT[checksum % CONTEXT.length]
    end
  end

  def is_a_dj_playlist?(str)
    /^\d{4}/.match?(str)
  end
end
