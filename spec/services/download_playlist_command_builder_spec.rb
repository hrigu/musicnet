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
        "--audio youtube bandcamp --save-errors FusionDark-errors.txt --simple-tui"
      )
    end

    it "verwendet die spotify_id, wenn kein playlist.url vorhanden ist" do
      playlist = Playlist.new(name: "Fusion Dark", url: nil, spotify_id: "spotify_id_1")

      expect(described_class.new(playlist).build).to eq(
        "spotdl sync https://open.spotify.com/playlist/spotify_id_1 --save-file FusionDark.spotdl " \
        "--sync-without-deleting --user-auth --format m4a " \
        "--audio youtube bandcamp --save-errors FusionDark-errors.txt --simple-tui"
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

    def create_missing_tracks(playlist, count)
      album = Album.create!(spotify_id: "alb-cpc-#{playlist.id}", name: "Album")
      count.times.map do |i|
        track = Track.create!(spotify_id: "trk-cpc-#{playlist.id}-#{i}", name: "Track #{i}", album: album,
                              duration_ms: 200_000)
        PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
        track
      end
    end

    it "laedt bei 1 bis 10 fehlenden Tracks gezielt deren Track-URLs statt die Playlist zu syncen" do
      playlist = Playlist.create!(spotify_id: "pl-cpc-1", name: "Fusion Klein", public: true)
      tracks = create_missing_tracks(playlist, 2)

      command = described_class.new(playlist).build

      aggregate_failures do
        expect(command).to eq(
          "spotdl download https://open.spotify.com/track/#{tracks[0].spotify_id} " \
          "https://open.spotify.com/track/#{tracks[1].spotify_id} " \
          "--format m4a --audio youtube bandcamp --save-file playlist_#{playlist.id}_missing.spotdl " \
          "--save-errors playlist_#{playlist.id}_missing-errors.txt --simple-tui"
        )
        expect(command).to_not include("--user-auth")
        expect(command).to_not include("--sync-without-deleting")
      end
    end

    it "synct weiterhin die ganze Playlist, wenn mehr als 10 Tracks fehlen" do
      playlist = Playlist.create!(spotify_id: "pl-cpc-2", name: "Fusion Gross", public: true,
                                  url: "https://open.spotify.com/playlist/pl-cpc-2")
      create_missing_tracks(playlist, 11)

      command = described_class.new(playlist).build

      expect(command).to eq(
        "spotdl sync https://open.spotify.com/playlist/pl-cpc-2 --save-file FusionGross.spotdl " \
        "--sync-without-deleting --format m4a --audio youtube bandcamp --save-errors FusionGross-errors.txt " \
        "--simple-tui"
      )
    end

    it "synct weiterhin die ganze Playlist, wenn keine Tracks fehlen" do
      playlist = Playlist.create!(spotify_id: "pl-cpc-3", name: "Fusion Komplett", public: true,
                                  url: "https://open.spotify.com/playlist/pl-cpc-3")

      command = described_class.new(playlist).build

      expect(command).to eq(
        "spotdl sync https://open.spotify.com/playlist/pl-cpc-3 --save-file FusionKomplett.spotdl " \
        "--sync-without-deleting --format m4a --audio youtube bandcamp --save-errors FusionKomplett-errors.txt " \
        "--simple-tui"
      )
    end
  end

  describe "#save_file_path and #errors_file_path" do
    it "liefert die im Kommando verwendeten Dateipfade" do
      playlist = Playlist.new(name: "Fusion Dark", spotify_id: "spotify_id_1")
      builder = described_class.new(playlist)
      builder.build

      expect(builder.save_file_path).to eq("FusionDark.spotdl")
      expect(builder.errors_file_path).to eq("FusionDark-errors.txt")
    end
  end
end
