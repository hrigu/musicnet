# frozen_string_literal: true

require "rails_helper"

RSpec.describe SpotifyPlaylistsGateway do
  let(:user) { instance_double(User, spotify_user: spotify_user) }
  let(:spotify_user) { double("RSpotify::User", id: "spotify-user-1") }
  let(:gateway) { described_class.new(user) }

  describe "#all" do
    it "holt alle Seiten und filtert auf eigene Playlists, die einer Library entsprechen" do
      Library.create!(name: "Fusion", keyword: "fusion")
      Library.create!(name: "Blues", keyword: "blues")
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

    it "berücksichtigt frei konfigurierte Libraries, nicht nur Fusion/Blues" do
      Library.create!(name: "Deep House", keyword: "house")
      own_house = spotify_playlist(id: "pl-5", name: "Deep House Vibes", owner_id: "spotify-user-1")

      allow(spotify_user).to receive(:playlists).with(limit: 50, offset: 0).and_return([own_house])
      allow(spotify_user).to receive(:playlists).with(limit: 50, offset: 50).and_return([])

      expect(gateway.all).to contain_exactly(own_house)
    end
  end

  describe "#find" do
    it "sucht eine Playlist über die Seiten hinweg" do
      target = spotify_playlist(id: "pl-2", name: "Blues Favorites", owner_id: "spotify-user-1")

      allow(spotify_user).to receive(:playlists).with(limit: 50, offset: 0)
                                                .and_return([spotify_playlist(id: "pl-1", name: "Fusion Favorites",
                                                                              owner_id: "spotify-user-1")])
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

    it "überspringt Ids, für die die API kein Album liefert (nil-Einträge)" do
      allow(RSpotify::Album).to receive(:find).with(%w[alb-1 alb-2])
                                              .and_return([double("RSpotify::Album", id: "alb-1"), nil])

      expect(gateway.albums_by_id(%w[alb-1 alb-2]).keys).to eq(["alb-1"])
    end

    it "macht ohne Ids keinen API-Aufruf" do
      expect(RSpotify::Album).to_not receive(:find)

      expect(gateway.albums_by_id([])).to eq({})
    end

    it "retryt bei 429 (Rate Limit) mit Backoff und liefert beim späteren Erfolg das Ergebnis" do
      success = [double("RSpotify::Album", id: "alb-1")]
      call_count = 0

      allow(RSpotify::Album).to receive(:find) do
        call_count += 1
        raise RestClient::TooManyRequests.new(nil, 429) if call_count < 3

        success
      end
      allow(gateway).to receive(:sleep)
      allow(Rails.logger).to receive(:warn)

      result = gateway.albums_by_id(["alb-1"])

      aggregate_failures do
        expect(result["alb-1"]).to eq(success.first)
        expect(gateway).to have_received(:sleep).twice
      end
    end

    it "gibt nach Ausschöpfen der Retries auf und loggt den letzten Fehler" do
      too_many_requests = RestClient::TooManyRequests.new(nil, 429)

      allow(RSpotify::Album).to receive(:find).and_raise(too_many_requests)
      allow(gateway).to receive(:sleep)
      allow(Rails.logger).to receive(:warn)

      aggregate_failures do
        expect(gateway.albums_by_id(["alb-1"])).to eq({})
        expect(gateway).to have_received(:sleep).exactly(3).times
        expect(Rails.logger).to have_received(:warn).with(/Spotify-Batch-Lookup fehlgeschlagen/)
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
      playlist = spotify_playlist(id: "pl-1", name: "Fusion Favorites", owner_id: "spotify-user-1",
                                  tracks: [first, second])

      allow(playlist).to receive(:tracks).with(limit: 100, offset: 0).and_return([first])
      allow(playlist).to receive(:tracks).with(limit: 100, offset: 100).and_return([second])
      allow(playlist).to receive(:tracks).with(limit: 100, offset: 200).and_return([])

      tracks, added_at_by_track_id = gateway.tracks_for(playlist)

      expect(tracks).to eq([first, second])
      expect(added_at_by_track_id.keys).to contain_exactly("trk-1", "trk-2")
    end
  end

  describe "#rename_playlist" do
    it "aendert den Namen auf Spotify und liefert die neue snapshot_id" do
      playlist = Playlist.create!(spotify_id: "pl-1", name: "Alt")
      spot_playlist = spotify_playlist(id: "pl-1", name: "Alt", owner_id: "spotify-user-1")
      renamed = spotify_playlist(id: "pl-1", name: "Neu", owner_id: "spotify-user-1", snapshot_id: "snap-neu")
      allow(RSpotify::Playlist).to receive(:find).with("spotify-user-1", "pl-1").and_return(spot_playlist, renamed)
      allow(spot_playlist).to receive(:change_details!).with(name: "Neu")

      expect(gateway.rename_playlist(playlist, "Neu")).to eq("snap-neu")
      expect(spot_playlist).to have_received(:change_details!).with(name: "Neu")
    end

    it "wandelt einen Spotify-Fehler in SpotifyWriteError" do
      playlist = Playlist.create!(spotify_id: "pl-1", name: "Alt")
      allow(RSpotify::Playlist).to receive(:find).and_raise(RestClient::BadRequest)

      expect { gateway.rename_playlist(playlist, "Neu") }.to raise_error(SpotifyPlaylistsGateway::SpotifyWriteError)
    end
  end

  describe "#add_track" do
    it "fuegt den Track ueber seine Spotify-Uri hinzu und liefert die neue snapshot_id" do
      playlist = Playlist.create!(spotify_id: "pl-1", name: "Playlist")
      track = Track.create!(spotify_id: "trk-1", name: "Track",
                            album: Album.create!(spotify_id: "alb-1", name: "Album"))
      spot_playlist = spotify_playlist(id: "pl-1", name: "Playlist", owner_id: "spotify-user-1",
                                       snapshot_id: "snap-add")
      allow(RSpotify::Playlist).to receive(:find).with("spotify-user-1", "pl-1").and_return(spot_playlist)
      allow(spot_playlist).to receive(:add_tracks!)

      expect(gateway.add_track(playlist, track)).to eq("snap-add")
      expect(spot_playlist).to have_received(:add_tracks!).with(["spotify:track:trk-1"])
    end

    it "wandelt einen Spotify-Fehler in SpotifyWriteError" do
      playlist = Playlist.create!(spotify_id: "pl-1", name: "Playlist")
      track = Track.create!(spotify_id: "trk-1", name: "Track",
                            album: Album.create!(spotify_id: "alb-1", name: "Album"))
      allow(RSpotify::Playlist).to receive(:find).and_raise(RestClient::BadRequest)

      expect { gateway.add_track(playlist, track) }.to raise_error(SpotifyPlaylistsGateway::SpotifyWriteError)
    end
  end

  describe "#remove_track" do
    it "entfernt den Track und liefert die neue snapshot_id" do
      playlist = Playlist.create!(spotify_id: "pl-1", name: "Playlist")
      track = Track.create!(spotify_id: "trk-1", name: "Track",
                            album: Album.create!(spotify_id: "alb-1", name: "Album"))
      spot_playlist = spotify_playlist(id: "pl-1", name: "Playlist", owner_id: "spotify-user-1",
                                       snapshot_id: "snap-remove")
      allow(RSpotify::Playlist).to receive(:find).with("spotify-user-1", "pl-1").and_return(spot_playlist)
      captured_tracks = nil
      allow(spot_playlist).to receive(:remove_tracks!) { |tracks| captured_tracks = tracks }

      expect(gateway.remove_track(playlist, track)).to eq("snap-remove")
      expect(captured_tracks.map(&:uri)).to eq(["spotify:track:trk-1"])
    end

    it "wandelt einen Spotify-Fehler in SpotifyWriteError" do
      playlist = Playlist.create!(spotify_id: "pl-1", name: "Playlist")
      track = Track.create!(spotify_id: "trk-1", name: "Track",
                            album: Album.create!(spotify_id: "alb-1", name: "Album"))
      allow(RSpotify::Playlist).to receive(:find).and_raise(RestClient::BadRequest)

      expect { gateway.remove_track(playlist, track) }.to raise_error(SpotifyPlaylistsGateway::SpotifyWriteError)
    end
  end
end
