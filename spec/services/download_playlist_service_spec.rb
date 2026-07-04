# frozen_string_literal: true

require "rails_helper"

RSpec.describe DownloadPlaylistService do
  describe "#download" do
    def build_playlist(url:)
      Playlist.new(name: "Fusion Dark", url: url, spotify_id: "spotify_id_1")
    end

    def stub_audio_features_extraction
      extraction = instance_double(AudioFeaturesExtractionService, extract_missing: nil)
      allow(AudioFeaturesExtractionService).to receive(:new).and_return(extraction)
      extraction
    end

    before { stub_audio_features_extraction }

    it "ruft system mit dem korrekten spotdl-sync-Kommando auf, wenn playlist.url gesetzt ist" do
      playlist = build_playlist(url: "https://open.spotify.com/playlist/abc123")
      service = described_class.new(playlist)
      allow(service).to receive(:system).and_return(true)

      service.download

      expect(service).to have_received(:system).with(
        "spotdl sync https://open.spotify.com/playlist/abc123 --save-file FusionDark.spotdl " \
        "--sync-without-deleting --user-auth --format m4a " \
        "--audio youtube bandcamp",
        chdir: Rails.root.join("downloads/tracks")
      )
    end

    it "baut die Playlist-URL aus spotify_id, wenn playlist.url fehlt" do
      playlist = build_playlist(url: nil)
      service = described_class.new(playlist)
      allow(service).to receive(:system).and_return(true)

      service.download

      expect(service).to have_received(:system).with(
        "spotdl sync https://open.spotify.com/playlist/spotify_id_1 --save-file FusionDark.spotdl " \
        "--sync-without-deleting --user-auth --format m4a " \
        "--audio youtube bandcamp",
        chdir: Rails.root.join("downloads/tracks")
      )
    end

    it "weist einen zweiten Download ab, solange einer läuft" do
      playlist = build_playlist(url: "https://open.spotify.com/playlist/abc123")
      service = described_class.new(playlist)
      allow(service).to receive(:system).and_return(true)

      DownloadPlaylistService::DOWNLOAD_LOCK.lock
      begin
        expect { service.download }.to raise_error(DownloadPlaylistService::DownloadAlreadyRunningError)
      ensure
        DownloadPlaylistService::DOWNLOAD_LOCK.unlock
      end
    end

    it "gibt den Lock nach einem Download wieder frei" do
      playlist = build_playlist(url: "https://open.spotify.com/playlist/abc123")
      service = described_class.new(playlist)
      allow(service).to receive(:system).and_return(true)

      service.download

      expect(DownloadPlaylistService::DOWNLOAD_LOCK).to_not be_locked
    end

    it "wechselt vorher ins downloads/tracks-Verzeichnis" do
      playlist = build_playlist(url: "https://open.spotify.com/playlist/abc123")
      service = described_class.new(playlist)
      allow(service).to receive(:system).and_return(true)

      service.download

      expect(service).to have_received(:system).with(anything, chdir: Rails.root.join("downloads/tracks"))
    end

    it "ruft nach erfolgreichem Download die Audio-Feature-Extraktion für die Playlist-Tracks auf" do
      playlist = build_playlist(url: "https://open.spotify.com/playlist/abc123")
      service = described_class.new(playlist)
      allow(service).to receive(:system).and_return(true)
      extraction = instance_double(AudioFeaturesExtractionService, extract_missing: nil)
      allow(AudioFeaturesExtractionService).to receive(:new).with(playlist.tracks).and_return(extraction)

      service.download

      expect(extraction).to have_received(:extract_missing)
    end

    it "ruft die Audio-Feature-Extraktion nicht auf, wenn der Download fehlschlägt" do
      playlist = build_playlist(url: "https://open.spotify.com/playlist/abc123")
      service = described_class.new(playlist)
      allow(service).to receive(:system).and_return(false)

      service.download

      expect(AudioFeaturesExtractionService).to_not have_received(:new)
    end
  end
end
