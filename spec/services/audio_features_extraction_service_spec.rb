# frozen_string_literal: true

require "rails_helper"

RSpec.describe AudioFeaturesExtractionService do
  let(:downloads_dir) { Rails.root.join("downloads/tracks") }
  let(:album) { Album.create!(name: "A Go Go", spotify_id: "alb-audio-features-batch") }

  describe "#extract_missing" do
    it "befüllt nur Tracks mit vorhandener Datei und noch leeren audio_features" do
      downloaded_without_features = Track.create!(name: "Hottentot", spotify_id: "trk-batch-1",
                                                  album: album, duration_ms: 200_000)
      downloaded_with_features = Track.create!(name: "Green Tea", spotify_id: "trk-batch-2",
                                               album: album, duration_ms: 200_000,
                                               audio_features: { "tempo" => 90.0, "energy" => 0.4 })
      not_downloaded = Track.create!(name: "RSpec Fehlt", spotify_id: "trk-batch-3",
                                     album: album, duration_ms: 200_000)

      files = ["RSpec Artist - Hottentot.m4a", "RSpec Artist - Green Tea.m4a"]
      FileUtils.mkdir_p(downloads_dir)
      files.each { |f| FileUtils.touch(downloads_dir.join(f)) }

      status = instance_double(Process::Status, success?: true)
      output = { rhythm: { bpm: 128.0 }, lowlevel: { average_loudness: 0.5 } }.to_json
      allow(Open3).to receive(:capture3).and_return([output, "", status])

      begin
        tracks = [downloaded_without_features, downloaded_with_features, not_downloaded]
        described_class.new(tracks).extract_missing
      ensure
        files.each { |f| FileUtils.rm_f(downloads_dir.join(f)) }
      end

      aggregate_failures do
        expect(downloaded_without_features.reload.audio_features).to eq("tempo" => 128.0, "energy" => 0.5)
        expect(downloaded_with_features.reload.audio_features).to eq("tempo" => 90.0, "energy" => 0.4)
        expect(not_downloaded.reload.audio_features).to be_nil
      end
    end
  end
end
