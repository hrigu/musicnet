# frozen_string_literal: true

require "open3"
require "json"

# Berechnet Tempo/Energy lokal aus der heruntergeladenen Audiodatei via Essentia. Laeuft im
# Docker-Image ghcr.io/mgoltzsche/essentia (Docker muss installiert und gestartet sein) statt
# als lokal kompiliertes Homebrew-Paket - der einzige Essentia-Homebrew-Tap (MTG/essentia)
# laesst sich auf Apple Silicon nicht zuverlaessig bauen (bekannte, offene Upstream-Issues).
# Ersatz fuer Spotifys dauerhaft gesperrten audio-features-Endpunkt (Intent 35).
class AudioFeaturesExtractor
  DOCKER_IMAGE = "ghcr.io/mgoltzsche/essentia"

  def initialize(track)
    @track = track
  end

  def extract
    return unless @track.track_path

    output, _stderr, status = run_essentia
    return unless status.success?

    features = parse_features(output)
    return unless features

    @track.update_column(:audio_features, features)
    Rails.logger.info(
      "AudioFeaturesExtractor: #{@track.name} -> tempo=#{features['tempo']}, energy=#{features['energy']}"
    )
  end

  private

  # "-" als Output-Pfad schreibt das Ergebnis als JSON auf stdout statt in eine Datei. capture3
  # (statt capture2) faengt zusaetzlich stderr ab - Essentia schreibt seine sehr ausfuehrlichen
  # [INFO]-Fortschrittszeilen dorthin; unabgefangen wuerden die (da nicht redirected) direkt in
  # den Rails-Log-Stream durchsickern. Wir loggen stattdessen selbst eine einzige Ergebniszeile.
  def run_essentia
    dir = File.dirname(@track.track_path)
    file_name = File.basename(@track.track_path)

    Open3.capture3(
      "docker", "run", "--rm", "-v", "#{dir}:/audio:ro", DOCKER_IMAGE,
      "essentia_streaming_extractor_music", "/audio/#{file_name}", "-", "/etc/essentia/profile.yaml"
    )
  end

  def parse_features(output)
    data = JSON.parse(output)
    tempo = data.dig("rhythm", "bpm")
    energy = data.dig("lowlevel", "average_loudness")
    return nil unless tempo || energy

    { "tempo" => tempo, "energy" => energy }
  rescue JSON::ParserError => e
    Rails.logger.warn("Essentia-Output fuer Track##{@track.id} nicht lesbar: #{e.message}")
    nil
  end
end
