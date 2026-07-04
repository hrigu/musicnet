# frozen_string_literal: true

# Berechnet Tempo/Energy nachtraeglich fuer bereits heruntergeladene Tracks, die vor der
# Essentia-Umstellung (Intent 35) heruntergeladen wurden und daher noch keine
# audio_features haben.
desc 'berechnet Tempo/Energy fuer bereits heruntergeladene Tracks ohne audio_features'
task extract_missing_audio_features: [:environment] do
  tracks = Track.where(audio_features: nil).to_a
  puts "Tracks ohne audio_features: #{tracks.size}"

  AudioFeaturesExtractionService.new(tracks).extract_missing

  puts "Fertig. Weiterhin ohne audio_features: #{Track.where(audio_features: nil).count}"
end
