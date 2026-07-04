# frozen_string_literal: true

# Ruft AudioFeaturesExtractor fuer alle Tracks einer Collection auf, die eine
# heruntergeladene Datei haben, aber noch keine Tempo-/Energy-Werte (Intent 35).
class AudioFeaturesExtractionService
  def initialize(tracks)
    @tracks = tracks
  end

  def extract_missing
    Track.preload_track_paths(@tracks)
    @tracks.select { |track| track.track_path && track.af.blank? }
           .each { |track| AudioFeaturesExtractor.new(track).extract }
  end
end
