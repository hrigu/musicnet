# frozen_string_literal: true

require "yaml"

# Berechnet Tempo/Energy lokal aus der heruntergeladenen Audiodatei via Essentia (CLI-Tool
# essentia_streaming_extractor_music, muss wie spotdl separat installiert sein und auf PATH
# liegen) - Ersatz fuer Spotifys dauerhaft gesperrten audio-features-Endpunkt (Intent 35).
class AudioFeaturesExtractor
  ESSENTIA_BINARY = "essentia_streaming_extractor_music"

  def initialize(track)
    @track = track
  end

  def extract
    return unless @track.track_path

    output_path = Rails.root.join("tmp", "essentia_track_#{@track.id}.yaml").to_s
    return unless run_essentia(output_path)

    features = parse_features(output_path)
    @track.update_column(:audio_features, features) if features
  ensure
    FileUtils.rm_f(output_path) if output_path
  end

  private

  def run_essentia(output_path)
    system(ESSENTIA_BINARY, @track.track_path, output_path, out: File::NULL, err: File::NULL)
  end

  def parse_features(output_path)
    data = YAML.safe_load_file(output_path)
    tempo = data.dig("rhythm", "bpm")
    energy = data.dig("lowlevel", "average_loudness")
    return nil unless tempo || energy

    { "tempo" => tempo, "energy" => energy }
  rescue Psych::Exception, Errno::ENOENT, TypeError => e
    Rails.logger.warn("Essentia-Output fuer Track##{@track.id} nicht lesbar: #{e.message}")
    nil
  end
end
