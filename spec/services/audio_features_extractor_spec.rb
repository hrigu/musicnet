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

  def stub_essentia_output(json_content, success: true, stderr: "")
    status = instance_double(Process::Status, success?: success)
    allow(Open3).to receive(:capture3).and_return([json_content, stderr, status])
  end

  describe "#extract" do
    it "speichert Tempo und Energy aus dem Essentia-Output" do
      track = Track.create!(name: "Hottentot", spotify_id: "trk-audio-features", album: album,
                            duration_ms: 200_000)
      file_name = "RSpec Artist - Hottentot.m4a"

      with_download_file(file_name) do
        stub_essentia_output({ rhythm: { bpm: 128.3 }, lowlevel: { average_loudness: 0.62 } }.to_json)

        described_class.new(track).extract
      end

      expect(track.reload.audio_features).to eq("tempo" => 128.3, "energy" => 0.62)
    end

    it "ruft docker run mit dem Track-Verzeichnis als Read-Only-Mount auf" do
      track = Track.create!(name: "Hottentot Docker", spotify_id: "trk-audio-features-docker", album: album,
                            duration_ms: 200_000)
      file_name = "RSpec Artist - Hottentot Docker.m4a"
      captured_args = nil

      with_download_file(file_name) do
        allow(Open3).to receive(:capture3) do |*args|
          captured_args = args
          status = instance_double(Process::Status, success?: true)
          [{ rhythm: { bpm: 100.0 } }.to_json, "", status]
        end

        described_class.new(track).extract
      end

      expect(captured_args).to eq([
        "docker", "run", "--rm", "-v", "#{downloads_dir}:/audio:ro",
        "ghcr.io/mgoltzsche/essentia",
        "essentia_streaming_extractor_music", "/audio/#{file_name}", "-", "/etc/essentia/profile.yaml"
      ])
    end

    it "loggt genau eine Zeile mit dem Ergebnis, statt Essentias stderr-Ausgabe durchzulassen" do
      track = Track.create!(name: "Hottentot Leise", spotify_id: "trk-audio-features-quiet", album: album,
                            duration_ms: 200_000)
      file_name = "RSpec Artist - Hottentot Leise.m4a"

      with_download_file(file_name) do
        stub_essentia_output({ rhythm: { bpm: 128.3 }, lowlevel: { average_loudness: 0.62 } }.to_json,
                             stderr: "[   INFO   ] MusicExtractorSVM: adding SVM model ...\n[   INFO   ] All done")
        allow(Rails.logger).to receive(:info).and_call_original

        described_class.new(track).extract
      end

      expect(Rails.logger).to have_received(:info).with(
        "AudioFeaturesExtractor: Hottentot Leise -> tempo=128.3, energy=0.62"
      ).once
    end

    it "macht nichts, wenn keine Datei zum Track gefunden wird" do
      track = Track.create!(name: "RSpec Unbekannt", spotify_id: "trk-audio-features-missing",
                            album: album, duration_ms: 200_000)
      allow(Open3).to receive(:capture3)

      described_class.new(track).extract

      aggregate_failures do
        expect(Open3).to_not have_received(:capture3)
        expect(track.reload.audio_features).to be_nil
      end
    end

    it "lässt audio_features leer, wenn der essentia-Aufruf fehlschlägt" do
      track = Track.create!(name: "RSpec Fehlschlag", spotify_id: "trk-audio-features-fail",
                            album: album, duration_ms: 200_000)
      file_name = "RSpec Artist - RSpec Fehlschlag.m4a"

      with_download_file(file_name) do
        stub_essentia_output("", success: false)

        described_class.new(track).extract
      end

      expect(track.reload.audio_features).to be_nil
    end

    it "lässt audio_features leer und loggt, wenn der Output kein verwertbares JSON ist" do
      track = Track.create!(name: "RSpec Kaputt", spotify_id: "trk-audio-features-broken",
                            album: album, duration_ms: 200_000)
      file_name = "RSpec Artist - RSpec Kaputt.m4a"

      with_download_file(file_name) do
        stub_essentia_output("not valid json")
        allow(Rails.logger).to receive(:warn)

        described_class.new(track).extract

        expect(Rails.logger).to have_received(:warn)
      end

      expect(track.reload.audio_features).to be_nil
    end

    it "lässt audio_features leer, wenn weder bpm noch average_loudness im Output stehen" do
      track = Track.create!(name: "RSpec Leer", spotify_id: "trk-audio-features-empty",
                            album: album, duration_ms: 200_000)
      file_name = "RSpec Artist - RSpec Leer.m4a"

      with_download_file(file_name) do
        stub_essentia_output({ metadata: { version: "2.1" } }.to_json)

        described_class.new(track).extract
      end

      expect(track.reload.audio_features).to be_nil
    end
  end
end
