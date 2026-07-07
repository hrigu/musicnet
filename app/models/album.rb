# frozen_string_literal: true

class Album < ApplicationRecord
  # Die Tracks des Albums, die in mindestens einer Playlist vorhanden sind
  has_many :tracks
  # Die Künstler welche auf den Tracks
  has_many :artists, -> { distinct }, through: :tracks

  # Spotify liefert release_date je nach release_date_precision unvollständig
  # ("1970" bei Precision "year", "2000-05" bei "month") statt eines vollen Datums - die
  # date-Spalte kann so einen String nicht parsen und castet ihn sonst stillschweigend zu
  # nil, ohne Fehler. Fehlende Monat/Tag-Anteile werden daher mit "-01" ergänzt.
  def self.normalize_release_date(raw)
    return nil if raw.blank?

    case raw
    when /\A\d{4}\z/ then "#{raw}-01-01"
    when /\A\d{4}-\d{2}\z/ then "#{raw}-01"
    else raw
    end
  end
end
