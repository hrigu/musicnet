# frozen_string_literal: true

module RecentlyPlayedHelper
  # Zeigt den per LocationNameResolver aufgeloesten Ortsnamen; solange die Aufloesung noch
  # aussteht oder fehlgeschlagen ist (Intent 87 Nachtrag), Rohkoordinaten als Fallback statt gar
  # nichts - Soft-Failure, kein verlorener Wert.
  def playback_location_label(playback)
    return playback.location_name if playback.location_name.present?
    return "#{playback.latitude}, #{playback.longitude}" if playback.latitude && playback.longitude

    nil
  end
end
