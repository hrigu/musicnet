# frozen_string_literal: true

require "rails_helper"

RSpec.describe DownloadPlaylistService do
  describe "#download" do
    def build_playlist(url:)
      Playlist.new(name: "Fusion Dark", url: url, spotify_id: "spotify_id_1")
    end

    it "ruft system mit dem korrekten spotdl-sync-Kommando auf, wenn playlist.url gesetzt ist" do
      playlist = build_playlist(url: "https://open.spotify.com/playlist/abc123")
      service = described_class.new(playlist)
      allow(Dir).to receive(:chdir).and_yield
      allow(service).to receive(:system).and_return(true)

      service.download

      expect(service).to have_received(:system).with(
        "spotdl sync https://open.spotify.com/playlist/abc123 --save-file FusionDark.spotdl " \
        "--user-auth --format m4a"
      )
    end

    it "baut die Playlist-URL aus spotify_id, wenn playlist.url fehlt" do
      playlist = build_playlist(url: nil)
      service = described_class.new(playlist)
      allow(Dir).to receive(:chdir).and_yield
      allow(service).to receive(:system).and_return(true)

      service.download

      expect(service).to have_received(:system).with(
        "spotdl sync https://open.spotify.com/playlist/spotify_id_1 --save-file FusionDark.spotdl " \
        "--user-auth --format m4a"
      )
    end

    it "wechselt vorher ins downloads/tracks-Verzeichnis" do
      playlist = build_playlist(url: "https://open.spotify.com/playlist/abc123")
      service = described_class.new(playlist)
      allow(service).to receive(:system).and_return(true)
      allow(Dir).to receive(:chdir).and_yield

      service.download

      expect(Dir).to have_received(:chdir).with(Rails.root.join("downloads/tracks"))
    end
  end
end
