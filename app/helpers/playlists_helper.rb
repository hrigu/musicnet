# frozen_string_literal: true

module PlaylistsHelper
  COLORS = %i[green blue yellow red lila orange black brown].freeze
  CONTEXT = [
    "bg-primary",
    "bg-secondary",
    "bg-success",
    "bg-danger",
    "bg-warning",
    "bg-info",
    "bg-light",
  ].freeze

  def playlist_short_name(playlist)
    playlist.name.gsub(/\bfusion\b/i, "_F_")
      .gsub(/\bblues\b/i, "_B_")
      .gsub(/\s+/, "")
      .gsub(/_+/, "_")
      .gsub(/\A_+/, "")
      .gsub(/_+\z/, "")
  end

  def playlist_color_class(playlist)
    if dj_playlist?(playlist.name)
      "bg-dark"
    else
      CONTEXT[checksum(playlist_short_name(playlist)) % CONTEXT.length]
    end
  end

  # playlist_tracks braucht bereits preload_track_paths (siehe
  # Playlist#playlist_tracks_for_display), sonst pro Track ein Verzeichnis-Scan.
  def all_tracks_downloaded?(playlist_tracks)
    playlist_tracks.all? { |pt| pt.track.track_path.present? }
  end

  # playlist.tracks braucht bereits preload_track_paths (siehe PlaylistsController#index),
  # sonst ein Verzeichnis-Scan pro Track statt einem fürs ganze Batch (Intent 61).
  def downloaded_tracks_count(playlist)
    playlist.tracks.count { |track| track.track_path.present? }
  end

  private

  def checksum(str)
    str.each_byte.sum
  end

  def dj_playlist?(name)
    /^\d{4}/.match?(name)
  end
end
