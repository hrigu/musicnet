# frozen_string_literal: true

require "rails_helper"

RSpec.describe Artist, type: :model do
  describe "#albums" do
    it "liefert jedes Album nur einmal, auch bei mehreren Tracks im selben Album" do
      album = Album.create!(name: "A Go Go", spotify_id: "alb1")
      artist = Artist.create!(name: "John Scofield", spotify_id: "art1")
      Track.create!(name: "Track 1", spotify_id: "trk1", album: album, artists: [artist])
      Track.create!(name: "Track 2", spotify_id: "trk2", album: album, artists: [artist])

      expect(artist.albums).to eq([album])
    end
  end

  describe "#playlists_of_the_tracks" do
    it "liefert alle Playlists, in denen der Artist vorkommt" do
      album = Album.create!(name: "Album", spotify_id: "alb1")
      artist = Artist.create!(name: "Artist", spotify_id: "art1")
      other_artist = Artist.create!(name: "Other", spotify_id: "art2")
      track = Track.create!(name: "Track", spotify_id: "trk1", album: album, artists: [artist])
      other_track = Track.create!(name: "Other Track", spotify_id: "trk2", album: album, artists: [other_artist])
      playlist = Playlist.create!(name: "Fusion", spotify_id: "pl1")
      other_playlist = Playlist.create!(name: "Blues", spotify_id: "pl2")
      PlaylistTrack.create!(playlist: playlist, track: track)
      PlaylistTrack.create!(playlist: other_playlist, track: other_track)

      expect(artist.playlists_of_the_tracks).to eq([playlist])
    end
  end
end
