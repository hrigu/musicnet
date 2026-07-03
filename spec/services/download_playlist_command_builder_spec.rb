# frozen_string_literal: true

require "rails_helper"

RSpec.describe DownloadPlaylistCommandBuilder do
  describe "#build" do
    it "baut den spotdl-Download-String aus der Playlist" do
      playlist = Playlist.new(name: "Fusion Dark", url: "https://open.spotify.com/playlist/abc123",
                              spotify_id: "spotify_id_1")

      expect(described_class.new(playlist).build).to eq(
        "spotdl sync https://open.spotify.com/playlist/abc123 --save-file FusionDark.spotdl " \
        "--sync-without-deleting --user-auth --format m4a"
      )
    end

    it "verwendet die spotify_id, wenn kein playlist.url vorhanden ist" do
      playlist = Playlist.new(name: "Fusion Dark", url: nil, spotify_id: "spotify_id_1")

      expect(described_class.new(playlist).build).to eq(
        "spotdl sync https://open.spotify.com/playlist/spotify_id_1 --save-file FusionDark.spotdl " \
        "--sync-without-deleting --user-auth --format m4a"
      )
    end
  end
end
