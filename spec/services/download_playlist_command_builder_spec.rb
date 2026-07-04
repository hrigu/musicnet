# frozen_string_literal: true

require "rails_helper"

RSpec.describe DownloadPlaylistCommandBuilder do
  describe "#build" do
    it "baut den spotdl-Download-String aus der Playlist" do
      playlist = Playlist.new(name: "Fusion Dark", url: "https://open.spotify.com/playlist/abc123",
                              spotify_id: "spotify_id_1")

      expect(described_class.new(playlist).build).to eq(
        "spotdl sync https://open.spotify.com/playlist/abc123 --save-file FusionDark.spotdl " \
        "--sync-without-deleting --user-auth --format m4a " \
        "--audio youtube bandcamp"
      )
    end

    it "verwendet die spotify_id, wenn kein playlist.url vorhanden ist" do
      playlist = Playlist.new(name: "Fusion Dark", url: nil, spotify_id: "spotify_id_1")

      expect(described_class.new(playlist).build).to eq(
        "spotdl sync https://open.spotify.com/playlist/spotify_id_1 --save-file FusionDark.spotdl " \
        "--sync-without-deleting --user-auth --format m4a " \
        "--audio youtube bandcamp"
      )
    end

    it "verlangt --user-auth, wenn die Playlist privat ist" do
      playlist = Playlist.new(name: "Fusion Dark", spotify_id: "spotify_id_1", public: false)

      expect(described_class.new(playlist).build).to include("--user-auth")
    end

    it "verzichtet auf --user-auth, wenn die Playlist oeffentlich ist" do
      playlist = Playlist.new(name: "Fusion Dark", spotify_id: "spotify_id_1", public: true)

      expect(described_class.new(playlist).build).not_to include("--user-auth")
    end
  end
end
