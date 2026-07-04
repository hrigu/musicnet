# frozen_string_literal: true

require "rails_helper"

RSpec.describe Playlist, type: :model do
  describe "#name_path_ready" do
    it "entfernt Leerzeichen aus dem Namen" do
      playlist = Playlist.new(name: "Fusion Dark")

      expect(playlist.name_path_ready).to eq("FusionDark")
    end
  end

  describe ".for_index" do
    it "liefert streng geladene Datensätze für den Index" do
      playlist = Playlist.create!(spotify_id: "pl-strict", name: "Fusion Strict")

      found = described_class.for_index.find_by!(spotify_id: playlist.spotify_id)

      expect(found.strict_loading?).to be(true)
      expect(found).to eq(playlist)
    end
  end

  describe "tracks_count counter cache" do
    it "setzt tracks_count beim Anlegen auf 0 und hält es bei PlaylistTracks aktuell" do
      playlist = Playlist.create!(spotify_id: "pl-cc-1", name: "Fusion Cache")
      album = Album.create!(spotify_id: "alb-cc-1", name: "Album Cache")
      track = Track.create!(spotify_id: "trk-cc-1", name: "Track Cache", album: album, duration_ms: 200_000)

      aggregate_failures do
        expect(playlist[:tracks_count]).to eq(0)
        expect { PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current) }
          .to change { playlist.reload[:tracks_count] }.from(0).to(1)
      end
    end
  end

  describe "#missing_tracks" do
    let(:downloads_dir) { Rails.root.join("downloads/tracks") }

    def with_download_file(file_name)
      FileUtils.mkdir_p(downloads_dir)
      FileUtils.touch(downloads_dir.join(file_name))
      yield
    ensure
      FileUtils.rm_f(downloads_dir.join(file_name))
    end

    it "liefert nur Tracks ohne lokale Datei" do
      album = Album.create!(spotify_id: "alb-mt-1", name: "Album")
      playlist = Playlist.create!(spotify_id: "pl-mt-1", name: "Fusion Missing")
      artist = Artist.create!(spotify_id: "art-mt-1", name: "RSpec Artist")
      present = Track.create!(spotify_id: "trk-mt-present", name: "RSpec Vorhanden", album: album,
                              artists: [artist], duration_ms: 200_000)
      missing = Track.create!(spotify_id: "trk-mt-missing", name: "RSpec Fehlend", album: album,
                              artists: [artist], duration_ms: 200_000)
      PlaylistTrack.create!(playlist: playlist, track: present, added_at: Time.current)
      PlaylistTrack.create!(playlist: playlist, track: missing, added_at: Time.current)

      with_download_file("RSpec Artist - RSpec Vorhanden.m4a") do
        expect(playlist.missing_tracks).to contain_exactly(missing)
      end
    end
  end

  describe "#playlist_tracks_for_display" do
    it "liefert streng geladene PlaylistTracks mit vorab geladenen Daten" do
      album = Album.create!(spotify_id: "alb-ptfd-1", name: "Album")
      playlist = Playlist.create!(spotify_id: "pl-ptfd-1", name: "Fusion Display")
      track = Track.create!(spotify_id: "trk-ptfd-1", name: "Track", album: album, duration_ms: 200_000)
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)

      records = playlist.playlist_tracks_for_display

      found = records.find_by!(track_id: track.id)
      expect(found.strict_loading?).to be(true)
      expect(found.track).to eq(track)
    end
  end
end
