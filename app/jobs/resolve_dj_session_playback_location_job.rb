# frozen_string_literal: true

# Loest den Ortsnamen fuer ein Playback im Hintergrund auf (Intent 87 Nachtrag), statt den
# Schreibpfad beim Track-Start durch den externen Nominatim-Call zu verzoegern - gleiches
# Async-Pattern wie DownloadMissingTracksJob (Intent 39).
class ResolveDjSessionPlaybackLocationJob < ApplicationJob
  def perform(dj_session_playback)
    return unless dj_session_playback.latitude && dj_session_playback.longitude

    name = LocationNameResolver.resolve(
      latitude: dj_session_playback.latitude, longitude: dj_session_playback.longitude
    )
    dj_session_playback.update_column(:location_name, name) if name
  end
end
