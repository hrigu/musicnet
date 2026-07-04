# frozen_string_literal: true

require "rails_helper"

RSpec.describe AudioFeaturesExtractor do
  let(:downloads_dir) { Rails.root.join("downloads/tracks") }
  let(:album) { Album.create!(name: "A Go Go", spotify_id: "alb-audio-features") }

  def with_download_file(file_name)
    FileUtils.mkdir_p(downloads_dir)
    FileUtils.touch(downloads_dir.join(file_name))
    yield
  ensure
    FileUtils.rm_f(downloads_dir.join(file_name))
  end

  def stub_essentia_output(extractor, yaml_content)
    allow(extractor).to receive(:system) do |*args|
      File.write(args[2], yaml_content)
      true
    end
  end

  describe "#extract" do
    it "speichert Tempo und Energy aus dem Essentia-Output" do
      track = Track.create!(name: "Hottentot", spotify_id: "trk-audio-features", album: album,
                            duration_ms: 200_000)
      file_name = "RSpec Artist - Hottentot.m4a"

      with_download_file(file_name) do
        extractor = described_class.new(track)
        stub_essentia_output(extractor, <<~YAML)
          rhythm:
            bpm: 128.3
          lowlevel:
            average_loudness: 0.62
        YAML

        extractor.extract
      end

      expect(track.reload.audio_features).to eq("tempo" => 128.3, "energy" => 0.62)
    end

    it "macht nichts, wenn keine Datei zum Track gefunden wird" do
      track = Track.create!(name: "RSpec Unbekannt", spotify_id: "trk-audio-features-missing",
                            album: album, duration_ms: 200_000)
      extractor = described_class.new(track)
      expect(extractor).to_not receive(:system)

      extractor.extract

      expect(track.reload.audio_features).to be_nil
    end

    it "lässt audio_features leer, wenn der essentia-Aufruf fehlschlägt" do
      track = Track.create!(name: "RSpec Fehlschlag", spotify_id: "trk-audio-features-fail",
                            album: album, duration_ms: 200_000)
      file_name = "RSpec Artist - RSpec Fehlschlag.m4a"

      with_download_file(file_name) do
        extractor = described_class.new(track)
        allow(extractor).to receive(:system).and_return(false)
        allow(Rails.logger).to receive(:warn)

        extractor.extract
      end

      expect(track.reload.audio_features).to be_nil
    end

    it "lässt audio_features leer und loggt, wenn der Output kein verwertbares YAML ist" do
      track = Track.create!(name: "RSpec Kaputt", spotify_id: "trk-audio-features-broken",
                            album: album, duration_ms: 200_000)
      file_name = "RSpec Artist - RSpec Kaputt.m4a"

      with_download_file(file_name) do
        extractor = described_class.new(track)
        stub_essentia_output(extractor, "not: [valid, yaml, :")
        allow(Rails.logger).to receive(:warn)

        extractor.extract

        expect(Rails.logger).to have_received(:warn)
      end

      expect(track.reload.audio_features).to be_nil
    end

    it "lässt audio_features leer, wenn weder bpm noch average_loudness im Output stehen" do
      track = Track.create!(name: "RSpec Leer", spotify_id: "trk-audio-features-empty",
                            album: album, duration_ms: 200_000)
      file_name = "RSpec Artist - RSpec Leer.m4a"

      with_download_file(file_name) do
        extractor = described_class.new(track)
        stub_essentia_output(extractor, "metadata:\n  version: 2.1\n")

        extractor.extract
      end

      expect(track.reload.audio_features).to be_nil
    end

    it "räumt die temporäre Essentia-Ausgabedatei nach dem Lauf auf" do
      track = Track.create!(name: "RSpec Cleanup", spotify_id: "trk-audio-features-cleanup",
                            album: album, duration_ms: 200_000)
      file_name = "RSpec Artist - RSpec Cleanup.m4a"
      output_path = Rails.root.join("tmp", "essentia_track_#{track.id}.yaml").to_s

      with_download_file(file_name) do
        extractor = described_class.new(track)
        stub_essentia_output(extractor, "rhythm:\n  bpm: 100.0\n")

        extractor.extract
      end

      expect(File).to_not exist(output_path)
    end
  end
end
