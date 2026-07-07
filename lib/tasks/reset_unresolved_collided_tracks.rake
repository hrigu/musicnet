# frozen_string_literal: true

# Setzt file_name/genre/audio_features fuer Tracks zurueck, die in einer Namenskollisions-Gruppe
# (Intent 74) stecken, aber auch nach Artist-Disambiguierung keine eigene passende Datei haben -
# ihre eigentliche Aufnahme wurde vermutlich nie heruntergeladen, sie zeigen bisher dauerhaft
# (und faelschlich) auf die Datei eines anderen, gleichnamigen Tracks. Nach diesem Reset gilt der
# Track wieder als "fehlend" (Track#track_path liefert nil, siehe TrackFileLocator.
# resolve_from_name_match, Intent 75) - die bestehende "Fehlende Tracks herunterladen"-Funktion
# (DownloadMissingTracksJob, Intent 39) laedt ihn dann ganz normal neu herunter, kein neuer
# Download-Code noetig.
desc "setzt file_name/genre/audio_features zurueck fuer Tracks ohne eigenen Artist-Treffer in einer Namenskollision"
task reset_unresolved_collided_tracks: [:environment] do
  file_entries = TrackFileLocator.download_file_entries
  collided_names = Track.where.not(file_name: nil).group(:name).having("count(*) > 1").pluck(:name)
  puts "Track-Namen mit mehreren Tracks: #{collided_names.size}"

  reset_tracks = []
  Track.where(name: collided_names).where.not(file_name: nil).find_each do |track|
    candidates = TrackFileLocator.matching_candidates(track, file_entries)
    next if candidates.size <= 1
    next if TrackFileLocator.disambiguate_by_artist(candidates, track)

    track.update_columns(file_name: nil, genre: nil, audio_features: nil)
    reset_tracks << track
  end

  puts "Zurueckgesetzt: #{reset_tracks.size} Tracks"
end
