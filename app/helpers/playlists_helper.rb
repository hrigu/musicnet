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

  private

  def checksum(str)
    str.each_byte.sum
  end

  def dj_playlist?(name)
    /^\d{4}/.match?(name)
  end
end
