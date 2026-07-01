# frozen_string_literal: true

require "rails_helper"

RSpec.describe DownloadTrackService do
  describe "#download" do
    it "ruft system mit dem korrekten spotdl-download-Kommando fuer einen Track auf" do
      track = Track.new(spotify_id: "trk1")
      service = described_class.new([track])
      allow(Dir).to receive(:chdir).and_yield
      allow(service).to receive(:system).and_return(true)

      service.download

      expect(service).to have_received(:system).with(
        "spotdl download https://open.spotify.com/track/trk1 --format m4a"
      )
    end

    it "fügt mehrere Track-URLs im Kommando leerzeichengetrennt zusammen" do
      tracks = [Track.new(spotify_id: "trk1"), Track.new(spotify_id: "trk2")]
      service = described_class.new(tracks)
      allow(Dir).to receive(:chdir).and_yield
      allow(service).to receive(:system).and_return(true)

      service.download

      expect(service).to have_received(:system).with(
        "spotdl download https://open.spotify.com/track/trk1 https://open.spotify.com/track/trk2 --format m4a"
      )
    end

    it "wechselt vorher ins downloads/tracks-Verzeichnis" do
      track = Track.new(spotify_id: "trk1")
      service = described_class.new([track])
      allow(service).to receive(:system).and_return(true)
      allow(Dir).to receive(:chdir).and_yield

      service.download

      expect(Dir).to have_received(:chdir).with(Rails.root.join("downloads/tracks"))
    end
  end
end
