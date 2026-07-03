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

  describe ".for_index" do
    it "liefert streng geladene Artists für den Index" do
      artist = Artist.create!(name: "Artist", spotify_id: "art-strict")

      found = described_class.for_index.find_by!(spotify_id: artist.spotify_id)

      expect(found.strict_loading?).to be(true)
      expect(found).to eq(artist)
    end
  end

  describe ".for_show" do
    it "liefert streng geladene Tracks für die Show" do
      album = Album.create!(name: "Album", spotify_id: "alb-show-strict")
      artist = Artist.create!(name: "Artist Show", spotify_id: "art-show-strict")
      Track.create!(name: "Track", spotify_id: "trk-show-strict", album: album, artists: [artist])

      found = described_class.for_show(artist).find_by!(spotify_id: "trk-show-strict")

      expect(found.strict_loading?).to be(true)
      expect(found).to be_a(Track)
    end
  end

  describe ".albums_for_show" do
    it "liefert streng geladene Alben für die Show" do
      album = Album.create!(name: "Album", spotify_id: "alb-albums-strict")
      artist = Artist.create!(name: "Artist Albums", spotify_id: "art-albums-strict")
      Track.create!(name: "Track", spotify_id: "trk-albums-strict", album: album, artists: [artist])

      found = described_class.albums_for_show(artist).find_by!(spotify_id: album.spotify_id)

      expect(found.strict_loading?).to be(true)
      expect(found).to eq(album)
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
