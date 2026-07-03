# frozen_string_literal: true

require "rails_helper"

RSpec.describe Playlist, type: :model do
  describe "#name_path_ready" do
    it "entfernt Leerzeichen aus dem Namen" do
      playlist = Playlist.new(name: "Fusion Dark")

      expect(playlist.name_path_ready).to eq("FusionDark")
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
end
