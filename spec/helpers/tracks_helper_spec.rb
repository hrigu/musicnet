# frozen_string_literal: true

require "rails_helper"

RSpec.describe TracksHelper, type: :helper do
  describe "#artist_names_for" do
    it "verbindet die Namen aller Künstler eines Tracks mit Komma" do
      album = Album.create!(spotify_id: "alb-th-1", name: "Album")
      artist_a = Artist.create!(spotify_id: "art-th-1", name: "Artist A")
      artist_b = Artist.create!(spotify_id: "art-th-2", name: "Artist B")
      track = Track.create!(spotify_id: "trk-th-1", name: "Track", album: album, artists: [artist_a, artist_b],
                            duration_ms: 200_000)

      expect(helper.artist_names_for(track)).to eq("Artist A, Artist B")
    end
  end

  describe "#playlist_names_for" do
    it "verbindet die Kurznamen aller Playlists eines Tracks mit Komma" do
      album = Album.create!(spotify_id: "alb-th-2", name: "Album")
      track = Track.create!(spotify_id: "trk-th-2", name: "Track", album: album, duration_ms: 200_000)
      playlist_a = Playlist.create!(spotify_id: "pl-th-1", name: "Fusion Dark")
      playlist_b = Playlist.create!(spotify_id: "pl-th-2", name: "Blues Bright")
      PlaylistTrack.create!(playlist: playlist_a, track: track, added_at: Time.current)
      PlaylistTrack.create!(playlist: playlist_b, track: track, added_at: Time.current)

      expected = "#{helper.playlist_short_name(playlist_a)}, #{helper.playlist_short_name(playlist_b)}"
      expect(helper.playlist_names_for(track)).to eq(expected)
    end

    it "funktioniert auch, wenn nur playlists statt playlist_tracks preloaded wurde" do
      album = Album.create!(spotify_id: "alb-th-3", name: "Album")
      track = Track.create!(spotify_id: "trk-th-3", name: "Track", album: album, duration_ms: 200_000)
      playlist = Playlist.create!(spotify_id: "pl-th-3", name: "Fusion Only")
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)

      reloaded = Track.preload(:playlists).find(track.id)

      expect(helper.playlist_names_for(reloaded)).to eq(helper.playlist_short_name(playlist))
    end
  end
end
