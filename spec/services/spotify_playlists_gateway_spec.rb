# frozen_string_literal: true

require "rails_helper"

RSpec.describe SpotifyPlaylistsGateway do
  let(:user) { instance_double(User, spotify_user: spotify_user) }
  let(:spotify_user) { double("RSpotify::User", id: "spotify-user-1") }
  let(:gateway) { described_class.new(user) }

  describe "#all" do
    it "holt alle Seiten und filtert auf eigene Fusion-/Blues-Playlists" do
      own_fusion = spotify_playlist(id: "pl-1", name: "Fusion Favorites", owner_id: "spotify-user-1")
      own_blues = spotify_playlist(id: "pl-2", name: "Blues Favorites", owner_id: "spotify-user-1")
      foreign = spotify_playlist(id: "pl-3", name: "Fusion Foreign", owner_id: "other-user")
      irrelevant = spotify_playlist(id: "pl-4", name: "Sommerhits", owner_id: "spotify-user-1")

      allow(spotify_user).to receive(:playlists).with(limit: 50, offset: 0)
        .and_return([own_fusion, foreign, irrelevant])
      allow(spotify_user).to receive(:playlists).with(limit: 50, offset: 50)
        .and_return([own_blues])
      allow(spotify_user).to receive(:playlists).with(limit: 50, offset: 100)
        .and_return([])

      expect(gateway.all).to contain_exactly(own_fusion, own_blues)
    end
  end

  describe "#find" do
    it "sucht eine Playlist über die Seiten hinweg" do
      target = spotify_playlist(id: "pl-2", name: "Blues Favorites", owner_id: "spotify-user-1")

      allow(spotify_user).to receive(:playlists).with(limit: 50, offset: 0)
        .and_return([spotify_playlist(id: "pl-1", name: "Fusion Favorites", owner_id: "spotify-user-1")])
      allow(spotify_user).to receive(:playlists).with(limit: 50, offset: 50)
        .and_return([target])
      allow(spotify_user).to receive(:playlists).with(limit: 50, offset: 100)
        .and_return([])

      expect(gateway.find("pl-2")).to eq(target)
    end

    it "gibt nil zurück, wenn die Playlist nicht existiert" do
      allow(spotify_user).to receive(:playlists).and_return([])

      expect(gateway.find("pl-missing")).to be_nil
    end
  end

  describe "#tracks_for" do
    it "holt alle Tracks einer Playlist inklusive added_at-Map über die Seiten hinweg" do
      album = spotify_album(id: "alb-1", name: "A Go Go")
      artist = spotify_artist(id: "art-1", name: "John Scofield")
      first = spotify_track(id: "trk-1", name: "Hottentot", album: album, artists: [artist])
      second = spotify_track(id: "trk-2", name: "Green Tea", album: album, artists: [artist])
      playlist = spotify_playlist(id: "pl-1", name: "Fusion Favorites", owner_id: "spotify-user-1", tracks: [first, second])

      allow(playlist).to receive(:tracks).with(limit: 100, offset: 0).and_return([first])
      allow(playlist).to receive(:tracks).with(limit: 100, offset: 100).and_return([second])
      allow(playlist).to receive(:tracks).with(limit: 100, offset: 200).and_return([])

      tracks, added_at_by_track_id = gateway.tracks_for(playlist)

      expect(tracks).to eq([first, second])
      expect(added_at_by_track_id.keys).to contain_exactly("trk-1", "trk-2")
    end
  end
end
