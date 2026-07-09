# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImportStandaloneSpotifyTrackService do
  describe ".import" do
    def stub_spotify_track(id:, name:, artist_name:, album_name:)
      track = RSpotify::Track.new(
        "id" => id, "name" => name, "duration_ms" => 123_456, "popularity" => 70,
        "external_urls" => { "spotify" => "https://open.spotify.com/track/#{id}" },
        "album" => {
          "id" => "alb-#{id}", "name" => album_name, "release_date" => "2020-01-01", "popularity" => 60,
          "external_urls" => { "spotify" => "https://open.spotify.com/album/alb-#{id}" }
        },
        "artists" => [{ "id" => "art-#{id}", "name" => artist_name, "popularity" => 55 }]
      )
      allow(RSpotify::Track).to receive(:find).with(id).and_return(track)
      track
    end

    it "importiert einen neuen Track ohne Playlist-Zuordnung" do
      stub_spotify_track(id: "standalone-1", name: "RSpec Standalone Track", artist_name: "RSpec Standalone Artist",
                         album_name: "RSpec Standalone Album")

      track = described_class.import("standalone-1")

      aggregate_failures do
        expect(track).to be_persisted
        expect(track.name).to eq("RSpec Standalone Track")
        expect(track.album.name).to eq("RSpec Standalone Album")
        expect(track.artists.map(&:name)).to eq(["RSpec Standalone Artist"])
        expect(track.playlists).to be_empty
      end
    end

    it "ruft RSpotify nicht auf und gibt den bestehenden Track zurueck, wenn er schon lokal existiert" do
      album = Album.create!(name: "Album vorhanden", spotify_id: "alb-standalone-2")
      existing = Track.create!(name: "RSpec Schon Da", spotify_id: "standalone-2", album:, duration_ms: 200_000)
      allow(RSpotify::Track).to receive(:find)

      track = described_class.import("standalone-2")

      aggregate_failures do
        expect(track).to eq(existing)
        expect(RSpotify::Track).to_not have_received(:find)
      end
    end
  end
end
