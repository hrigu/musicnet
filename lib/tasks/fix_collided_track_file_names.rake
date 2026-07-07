# frozen_string_literal: true

# Behebt Faelle, in denen backfill_track_file_names (Intent 72) mehrere gleichnamige Tracks
# (unterschiedlicher Artist) faelschlich auf dieselbe Datei gemappt hat, weil das damalige
# Namens-Matching artist-blind war (Intent 74). Nutzt TrackFileLocator.resolve_from_name_match,
# das inzwischen bei mehreren Kandidaten den Artist-Namen des Tracks beruecksichtigt. Bleibt die
# Zuordnung mehrdeutig (kein Kandidat enthaelt einen Artist-Namen), wird nichts veraendert - kein
# erneutes Raten. genre/audio_features werden fuer tatsaechlich korrigierte Tracks zurueckgesetzt,
# da beide als Read-Through-Cache aus der (bisher falschen) Datei stammen koennen.
desc "korrigiert file_name fuer Tracks, die durch Namenskollisionen falsch zugeordnet wurden"
task fix_collided_track_file_names: [:environment] do
  file_entries = TrackFileLocator.download_file_entries
  collided_names = Track.where.not(file_name: nil).group(:name).having("count(*) > 1").pluck(:name)
  puts "Track-Namen mit mehreren Tracks: #{collided_names.size}"

  corrected_tracks = []
  Track.where(name: collided_names).where.not(file_name: nil).find_each do |track|
    resolved_path = TrackFileLocator.resolve_from_name_match(track, file_entries)
    next unless resolved_path

    new_file_name = File.basename(resolved_path)
    next if new_file_name == track.file_name

    track.update_columns(file_name: new_file_name, genre: nil, audio_features: nil)
    corrected_tracks << track
  end

  AudioFeaturesExtractionService.new(corrected_tracks).extract_missing if corrected_tracks.any?

  puts "Korrigiert: #{corrected_tracks.size} Tracks"
end
