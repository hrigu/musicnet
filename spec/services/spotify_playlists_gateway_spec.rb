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

  describe "#audio_features_by_track_id" do
    it "holt die Audio-Features in 100er-Slices und liefert sie als Hash nach Track-Id" do
      ids = (1..150).map { |i| "trk-#{i}" }
      first_batch = ids.first(100).map { |id| double("RSpotify::AudioFeatures", id: id) }
      second_batch = ids.last(50).map { |id| double("RSpotify::AudioFeatures", id: id) }

      allow(RSpotify::AudioFeatures).to receive(:find).with(ids.first(100)).and_return(first_batch)
      allow(RSpotify::AudioFeatures).to receive(:find).with(ids.last(50)).and_return(second_batch)

      result = gateway.audio_features_by_track_id(ids)

      aggregate_failures do
        expect(result.keys).to eq(ids)
        expect(result["trk-1"]).to eq(first_batch.first)
        expect(result["trk-150"]).to eq(second_batch.last)
      end
    end

    it "überspringt Tracks, für die die API keine Audio-Features liefert (nil-Einträge)" do
      allow(RSpotify::AudioFeatures).to receive(:find).with(%w[trk-1 trk-2])
        .and_return([double("RSpotify::AudioFeatures", id: "trk-1"), nil])

      expect(gateway.audio_features_by_track_id(%w[trk-1 trk-2]).keys).to eq(["trk-1"])
    end

    it "loggt einen fehlgeschlagenen Batch-Aufruf und lässt dessen Slice im Ergebnis weg" do
      allow(RSpotify::AudioFeatures).to receive(:find).and_raise(RestClient::Forbidden)
      allow(Rails.logger).to receive(:warn)

      aggregate_failures do
        expect(gateway.audio_features_by_track_id(["trk-1"])).to eq({})
        expect(Rails.logger).to have_received(:warn)
      end
    end

    it "macht ohne Ids keinen API-Aufruf" do
      expect(RSpotify::AudioFeatures).to_not receive(:find)

      expect(gateway.audio_features_by_track_id([])).to eq({})
    end
  end

  describe "#albums_by_id" do
    it "holt die vollen Alben in 20er-Slices und liefert sie als Hash nach Album-Id" do
      ids = (1..25).map { |i| "alb-#{i}" }
      first_batch = ids.first(20).map { |id| double("RSpotify::Album", id: id) }
      second_batch = ids.last(5).map { |id| double("RSpotify::Album", id: id) }

      allow(RSpotify::Album).to receive(:find).with(ids.first(20)).and_return(first_batch)
      allow(RSpotify::Album).to receive(:find).with(ids.last(5)).and_return(second_batch)

      result = gateway.albums_by_id(ids)

      aggregate_failures do
        expect(result.keys).to eq(ids)
        expect(result["alb-25"]).to eq(second_batch.last)
      end
    end

    it "loggt einen fehlgeschlagenen Batch-Aufruf und lässt dessen Slice im Ergebnis weg" do
      allow(RSpotify::Album).to receive(:find).and_raise(RestClient::BadRequest)
      allow(Rails.logger).to receive(:warn)

      aggregate_failures do
        expect(gateway.albums_by_id(["alb-1"])).to eq({})
        expect(Rails.logger).to have_received(:warn)
      end
    end
  end

  describe "#artists_by_id" do
    it "holt die vollen Artists in 50er-Slices und liefert sie als Hash nach Artist-Id" do
      ids = (1..60).map { |i| "art-#{i}" }
      first_batch = ids.first(50).map { |id| double("RSpotify::Artist", id: id) }
      second_batch = ids.last(10).map { |id| double("RSpotify::Artist", id: id) }

      allow(RSpotify::Artist).to receive(:find).with(ids.first(50)).and_return(first_batch)
      allow(RSpotify::Artist).to receive(:find).with(ids.last(10)).and_return(second_batch)

      result = gateway.artists_by_id(ids)

      aggregate_failures do
        expect(result.keys).to eq(ids)
        expect(result["art-60"]).to eq(second_batch.last)
      end
    end

    it "loggt einen fehlgeschlagenen Batch-Aufruf und lässt dessen Slice im Ergebnis weg" do
      allow(RSpotify::Artist).to receive(:find).and_raise(RestClient::BadRequest)
      allow(Rails.logger).to receive(:warn)

      aggregate_failures do
        expect(gateway.artists_by_id(["art-1"])).to eq({})
        expect(Rails.logger).to have_received(:warn)
      end
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
