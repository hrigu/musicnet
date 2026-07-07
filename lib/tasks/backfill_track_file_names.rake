# frozen_string_literal: true

# Befuellt file_name rueckwirkend fuer Tracks, die vor Intent 72 heruntergeladen wurden.
# Nutzt denselben Namens-Matching-Weg wie bisher (TrackFileLocator) - bei historischen
# Namenskollisionen (zwei exakt gleichnamige Tracks) kann das weiterhin beiden Tracks
# dieselbe Datei zuweisen, das laesst sich nur manuell pruefen und korrigieren.
desc 'befuellt file_name rueckwirkend fuer bereits heruntergeladene Tracks'
task backfill_track_file_names: [:environment] do
  tracks = Track.where(file_name: nil).to_a
  puts "Tracks ohne file_name: #{tracks.size}"

  file_entries = TrackFileLocator.download_file_entries
  updated = tracks.count do |track|
    path = TrackFileLocator.resolve_track_path(track, file_entries)
    track.update_column(:file_name, File.basename(path)) if path
    path
  end

  puts "Fertig. file_name gesetzt fuer #{updated} Tracks. " \
       "Weiterhin ohne file_name: #{Track.where(file_name: nil).count}"
end
