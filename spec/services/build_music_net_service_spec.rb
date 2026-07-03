# frozen_string_literal: true

require "rails_helper"

RSpec.describe BuildMusicNetService do
  fixtures :users

  let(:user) { users(:one) }
  let(:spotify_user_id) { "spotify-user-1" }
  let(:artist) { spotify_artist(id: "art1", name: "John Scofield") }
  let(:album) { spotify_album(id: "alb1", name: "A Go Go") }
  let(:track) { spotify_track(id: "trk1", name: "Hottentot", album: album, artists: [artist]) }
  let(:playlist) { spotify_playlist(id: "pl1", name: "Fusion Favorites", owner_id: spotify_user_id, tracks: [track]) }

  def stub_spotify_playlists(playlists)
    spotify_user = double("RSpotify::User", id: spotify_user_id)
    allow(spotify_user).to receive(:playlists).with(limit: 50, offset: 0).and_return(playlists)
    allow(spotify_user).to receive(:playlists).with(limit: 50, offset: 50).and_return([])
    allow(user).to receive(:spotify_user).and_return(spotify_user)
  end

  describe "#build" do
    context "wenn eine Fusion-Playlist mit einem Track existiert" do
      before { stub_spotify_playlists([playlist]) }

      it "erstellt Playlist, Track, Album, Artist und PlaylistTrack" do
        BuildMusicNetService.new(user).build

        playlist_record = Playlist.find_by(spotify_id: "pl1")
        track_record = Track.find_by(spotify_id: "trk1")

        expect(playlist_record.name).to eq("Fusion Favorites")
        expect(track_record.name).to eq("Hottentot")
        expect(track_record.album.name).to eq("A Go Go")
        expect(track_record.artists.map(&:name)).to eq(["John Scofield"])
        expect(PlaylistTrack.find_by(playlist: playlist_record, track: track_record)).to be_present
      end

      it "legt bei einem erneuten Lauf keine Duplikate an" do
        2.times { BuildMusicNetService.new(user).build }

        expect(Playlist.where(spotify_id: "pl1").count).to eq(1)
        expect(Track.where(spotify_id: "trk1").count).to eq(1)
        expect(Album.where(spotify_id: "alb1").count).to eq(1)
        expect(Artist.where(spotify_id: "art1").count).to eq(1)
        expect(PlaylistTrack.count).to eq(1)
      end
    end

    context "wenn eine Fusion-Playlist einem anderen Spotify-User gehört" do
      let(:foreign_playlist) do
        spotify_playlist(id: "pl-foreign", name: "Fusion von jemand anderem", owner_id: "anderer-user", tracks: [track])
      end

      it "importiert diese Playlist nicht" do
        stub_spotify_playlists([foreign_playlist])

        BuildMusicNetService.new(user).build

        expect(Playlist.find_by(spotify_id: "pl-foreign")).to be_nil
      end
    end

    context "wenn eine eigene Playlist weder 'fusion' noch 'blues' im Namen hat" do
      let(:other_playlist) { spotify_playlist(id: "pl-other", name: "Sommerhits", owner_id: spotify_user_id, tracks: [track]) }

      it "importiert diese Playlist nicht" do
        stub_spotify_playlists([other_playlist])

        BuildMusicNetService.new(user).build

        expect(Playlist.find_by(spotify_id: "pl-other")).to be_nil
      end
    end

    context "wenn sich die snapshot_id einer Playlist nicht geändert hat" do
      it "überspringt die Playlist, ohne ihre Tracks von Spotify zu holen" do
        stub_spotify_playlists([playlist])
        BuildMusicNetService.new(user).build
        playlist_track_id = PlaylistTrack.first.id
        unchanged_playlist = spotify_playlist(id: "pl1", name: "Fusion Favorites", owner_id: spotify_user_id,
                                              tracks: [track])
        stub_spotify_playlists([unchanged_playlist])

        BuildMusicNetService.new(user).build

        aggregate_failures do
          expect(unchanged_playlist).to_not have_received(:tracks)
          expect(PlaylistTrack.first.id).to eq(playlist_track_id)
        end
      end
    end

    context "wenn sich die snapshot_id einer Playlist geändert hat" do
      it "gleicht die Playlist ab und aktualisiert Name und snapshot_id" do
        stub_spotify_playlists([playlist])
        BuildMusicNetService.new(user).build
        new_track = spotify_track(id: "trk2", name: "Green Tea", album: album, artists: [artist])
        changed_playlist = spotify_playlist(id: "pl1", name: "Blues Favorites", owner_id: spotify_user_id,
                                            tracks: [new_track], snapshot_id: "snap-neu")
        stub_spotify_playlists([changed_playlist])

        BuildMusicNetService.new(user).build

        playlist_record = Playlist.find_by(spotify_id: "pl1")
        aggregate_failures do
          expect(playlist_record.name).to eq("Blues Favorites")
          expect(playlist_record.snapshot_id).to eq("snap-neu")
          expect(playlist_record.tracks.map(&:name)).to eq(["Green Tea"])
          expect(Track.find_by(spotify_id: "trk1")).to be_nil
        end
      end
    end

    context "wenn eine zuvor synchronisierte Playlist auf Spotify nicht mehr existiert" do
      before do
        stub_spotify_playlists([playlist])
        BuildMusicNetService.new(user).build
        stub_spotify_playlists([])
      end

      it "löscht die verwaiste Playlist" do
        BuildMusicNetService.new(user).build

        expect(Playlist.find_by(spotify_id: "pl1")).to be_nil
      end

      it "löscht Track, Artist und Album, die keiner Playlist mehr zugeordnet sind" do
        BuildMusicNetService.new(user).build

        expect(Track.find_by(spotify_id: "trk1")).to be_nil
        expect(Artist.find_by(spotify_id: "art1")).to be_nil
        expect(Album.find_by(spotify_id: "alb1")).to be_nil
      end
    end

    context "wenn eine Playlist mehr als 100 Tracks enthält" do
      it "importiert alle Tracks über die 100er-Paginierung der API hinweg" do
        many_tracks = (1..120).map do |i|
          spotify_track(id: "bulk#{i}", name: "Bulk Track #{i}", album: album, artists: [artist])
        end
        big_playlist = spotify_playlist(id: "pl-big", name: "Blues Marathon", owner_id: spotify_user_id,
                                        tracks: many_tracks)
        stub_spotify_playlists([big_playlist])

        BuildMusicNetService.new(user).build

        expect(Playlist.find_by(spotify_id: "pl-big").tracks.count).to eq(120)
      end
    end

    context "wenn beim Import eines Tracks ein Fehler auftritt" do
      it "rollt die Playlist komplett zurück statt sie halb importiert zu lassen" do
        broken_track = spotify_track(id: "trk-broken", name: "Kaputt", album: album, artists: [artist])
        allow(broken_track).to receive(:artists).and_raise(RuntimeError, "Spotify-Fehler")
        playlist_with_broken_track = spotify_playlist(id: "pl1", name: "Fusion Favorites", owner_id: spotify_user_id,
                                                      tracks: [track, broken_track])
        stub_spotify_playlists([playlist_with_broken_track])

        expect { BuildMusicNetService.new(user).build }.to raise_error(RuntimeError, "Spotify-Fehler")

        aggregate_failures do
          expect(Playlist.find_by(spotify_id: "pl1")).to be_nil
          expect(Track.find_by(spotify_id: "trk1")).to be_nil
        end
      end
    end

    context "Batch-Lookups beim Anlegen neuer Tracks" do
      # Wie in der echten API: Playlist-Payloads enthalten nur simplified Alben/Artists
      # ohne popularity/release_date - diese Details dürfen nur aus den Batch-Lookups kommen.
      let(:album) do
        double("RSpotify::Album (simplified)", id: "alb1", name: "A Go Go",
                                               external_urls: { "spotify" => "https://open.spotify.com/album/alb1" })
      end
      let(:artist) { double("RSpotify::Artist (simplified)", id: "art1", name: "John Scofield") }

      before do
        stub_spotify_playlists([playlist])
        allow(RSpotify::AudioFeatures).to receive(:find).with(["trk1"])
          .and_return([double("RSpotify::AudioFeatures", id: "trk1", to_json: '{"energy":0.8,"tempo":120.0}')])
        allow(RSpotify::Album).to receive(:find).with(["alb1"])
          .and_return([double("RSpotify::Album", id: "alb1", popularity: 44, release_date: "2019-05-01")])
        allow(RSpotify::Artist).to receive(:find).with(["art1"])
          .and_return([double("RSpotify::Artist", id: "art1", popularity: 61)])
      end

      it "speichert Audio-Features, Album- und Artist-Details aus den Batch-Lookups" do
        BuildMusicNetService.new(user).build

        track_record = Track.find_by(spotify_id: "trk1")
        aggregate_failures do
          expect(track_record.audio_features).to eq('{"energy":0.8,"tempo":120.0}')
          expect(track_record.album.popularity).to eq(44)
          expect(track_record.album.release_date).to eq(Date.new(2019, 5, 1))
          expect(track_record.artists.first.popularity).to eq(61)
        end
      end

      it "bündelt die Audio-Features aller neuen Tracks einer Playlist in einem Aufruf" do
        second_track = spotify_track(id: "trk2", name: "Green Tea", album: album, artists: [artist])
        two_track_playlist = spotify_playlist(id: "pl1", name: "Fusion Favorites", owner_id: spotify_user_id,
                                              tracks: [track, second_track])
        stub_spotify_playlists([two_track_playlist])
        allow(RSpotify::AudioFeatures).to receive(:find).with(%w[trk1 trk2]).and_return([])

        BuildMusicNetService.new(user).build

        expect(RSpotify::AudioFeatures).to have_received(:find).once.with(%w[trk1 trk2])
      end

      it "fragt Audio-Features nur für lokal neue Tracks an" do
        local_album = Album.create!(spotify_id: "alb1", name: "A Go Go")
        Track.create!(spotify_id: "trk1", name: "Hottentot", album: local_album)

        BuildMusicNetService.new(user).build

        expect(RSpotify::AudioFeatures).to_not have_received(:find)
      end

      it "fragt lokal bereits vorhandene Alben und Artists nicht erneut an" do
        Album.create!(spotify_id: "alb1", name: "A Go Go")
        Artist.create!(spotify_id: "art1", name: "John Scofield")

        BuildMusicNetService.new(user).build

        aggregate_failures do
          expect(RSpotify::Album).to_not have_received(:find)
          expect(RSpotify::Artist).to_not have_received(:find)
        end
      end

      it "läuft bei fehlgeschlagenen Batch-Aufrufen durch und lässt die Detail-Felder leer" do
        allow(RSpotify::AudioFeatures).to receive(:find).and_raise(RestClient::Forbidden)
        allow(RSpotify::Album).to receive(:find).and_raise(RestClient::Forbidden)
        allow(RSpotify::Artist).to receive(:find).and_raise(RestClient::Forbidden)

        BuildMusicNetService.new(user).build

        track_record = Track.find_by(spotify_id: "trk1")
        aggregate_failures do
          expect(track_record).to be_present
          expect(track_record.album.popularity).to be_nil
          expect(track_record.artists.first.popularity).to be_nil
        end
      end
    end

    context "ServiceInfo" do
      it "sammelt die Namen neu erstellter Datensätze" do
        stub_spotify_playlists([playlist])

        info = BuildMusicNetService.new(user).build

        expect(info.hash[:playlists][:created]).to eq(["Fusion Favorites"])
        expect(info.hash[:tracks][:created]).to eq(["Hottentot"])
        expect(info.hash[:albums][:created]).to eq(["A Go Go"])
        expect(info.hash[:artists][:created]).to eq(["John Scofield"])
      end

      it "sammelt die Namen gelöschter Datensätze" do
        stub_spotify_playlists([playlist])
        BuildMusicNetService.new(user).build
        stub_spotify_playlists([])

        info = BuildMusicNetService.new(user).build

        # ServiceInfo#add haengt bei "deleted" das ganze Namens-Array in einem Rutsch an
        # (anders als bei "created", wo einzeln pro Datensatz angehaengt wird) - daher verschachtelt.
        expect(info.hash[:playlists][:deleted]).to eq([["Fusion Favorites"]])
        expect(info.hash[:tracks][:deleted]).to eq([["Hottentot"]])
      end
    end
  end

  describe "Parallelitäts-Schutz" do
    it "weist build und refresh_playlist ab, solange ein anderer Sync läuft" do
      stub_spotify_playlists([playlist])
      BuildMusicNetService::SYNC_LOCK.lock
      begin
        aggregate_failures do
          expect { BuildMusicNetService.new(user).build }
            .to raise_error(BuildMusicNetService::SyncAlreadyRunningError)
          expect { BuildMusicNetService.new(user).refresh_playlist(Playlist.new) }
            .to raise_error(BuildMusicNetService::SyncAlreadyRunningError)
        end
      ensure
        BuildMusicNetService::SYNC_LOCK.unlock
      end
    end

    it "gibt den Lock nach einem Sync wieder frei" do
      stub_spotify_playlists([playlist])

      BuildMusicNetService.new(user).build

      expect(BuildMusicNetService::SYNC_LOCK).to_not be_locked
    end
  end

  describe "#refresh_playlist" do
    let(:new_track) { spotify_track(id: "trk2", name: "Green Tea", album: album, artists: [artist]) }

    context "wenn die Spotify-Playlist einen neuen Track enthält" do
      it "fügt den Track der Playlist hinzu und meldet ihn als hinzugekommen" do
        stub_spotify_playlists([playlist])
        BuildMusicNetService.new(user).build
        playlist_record = Playlist.find_by(spotify_id: "pl1")
        updated_playlist = spotify_playlist(id: "pl1", name: "Fusion Favorites", owner_id: spotify_user_id,
                                            tracks: [track, new_track])
        stub_spotify_playlists([updated_playlist])

        info = BuildMusicNetService.new(user).refresh_playlist(playlist_record)

        aggregate_failures do
          expect(playlist_record.tracks.reload.map(&:name)).to contain_exactly("Hottentot", "Green Tea")
          expect(info.added).to eq(["Green Tea"])
          expect(info.removed).to be_empty
        end
      end
    end

    context "wenn ein lokaler Track auf Spotify nicht mehr in der Playlist ist" do
      it "löst den Track aus der Playlist, meldet ihn als entfernt und räumt Waisen auf" do
        stub_spotify_playlists([playlist])
        BuildMusicNetService.new(user).build
        playlist_record = Playlist.find_by(spotify_id: "pl1")
        updated_playlist = spotify_playlist(id: "pl1", name: "Fusion Favorites", owner_id: spotify_user_id,
                                            tracks: [new_track])
        stub_spotify_playlists([updated_playlist])

        info = BuildMusicNetService.new(user).refresh_playlist(playlist_record)

        aggregate_failures do
          expect(playlist_record.tracks.reload.map(&:name)).to eq(["Green Tea"])
          expect(info.added).to eq(["Green Tea"])
          expect(info.removed).to eq(["Hottentot"])
          expect(Track.find_by(spotify_id: "trk1")).to be_nil
        end
      end
    end

    context "wenn die Spotify-Playlist mehr als 100 Tracks enthält" do
      it "importiert alle Tracks über die 100er-Paginierung der API hinweg" do
        many_tracks = (1..120).map do |i|
          spotify_track(id: "bulk#{i}", name: "Bulk Track #{i}", album: album, artists: [artist])
        end
        stub_spotify_playlists([playlist])
        BuildMusicNetService.new(user).build
        playlist_record = Playlist.find_by(spotify_id: "pl1")
        updated_playlist = spotify_playlist(id: "pl1", name: "Fusion Favorites", owner_id: spotify_user_id,
                                            tracks: many_tracks)
        stub_spotify_playlists([updated_playlist])

        info = BuildMusicNetService.new(user).refresh_playlist(playlist_record)

        aggregate_failures do
          expect(playlist_record.tracks.reload.count).to eq(120)
          expect(info.added.size).to eq(120)
          expect(info.removed).to eq(["Hottentot"])
        end
      end
    end

    context "wenn die Playlist auf Spotify umbenannt wurde" do
      it "aktualisiert Name und snapshot_id" do
        stub_spotify_playlists([playlist])
        BuildMusicNetService.new(user).build
        playlist_record = Playlist.find_by(spotify_id: "pl1")
        renamed_playlist = spotify_playlist(id: "pl1", name: "Blues Favorites", owner_id: spotify_user_id,
                                            tracks: [track], snapshot_id: "snap-neu")
        stub_spotify_playlists([renamed_playlist])

        BuildMusicNetService.new(user).refresh_playlist(playlist_record)

        playlist_record.reload
        aggregate_failures do
          expect(playlist_record.name).to eq("Blues Favorites")
          expect(playlist_record.snapshot_id).to eq("snap-neu")
        end
      end
    end

    context "wenn beim Refresh der Import eines Tracks fehlschlägt" do
      it "lässt die Playlist unverändert (Rollback)" do
        stub_spotify_playlists([playlist])
        BuildMusicNetService.new(user).build
        playlist_record = Playlist.find_by(spotify_id: "pl1")
        broken_track = spotify_track(id: "trk-broken", name: "Kaputt", album: album, artists: [artist])
        allow(broken_track).to receive(:artists).and_raise(RuntimeError, "Spotify-Fehler")
        updated_playlist = spotify_playlist(id: "pl1", name: "Fusion Favorites", owner_id: spotify_user_id,
                                            tracks: [new_track, broken_track])
        stub_spotify_playlists([updated_playlist])

        expect do
          BuildMusicNetService.new(user).refresh_playlist(playlist_record)
        end.to raise_error(RuntimeError, "Spotify-Fehler")

        expect(playlist_record.tracks.reload.map(&:name)).to eq(["Hottentot"])
      end
    end

    context "wenn die Playlist auf Spotify nicht gefunden wird" do
      it "wirft einen verständlichen Fehler" do
        stub_spotify_playlists([playlist])
        BuildMusicNetService.new(user).build
        playlist_record = Playlist.find_by(spotify_id: "pl1")
        stub_spotify_playlists([])

        expect do
          BuildMusicNetService.new(user).refresh_playlist(playlist_record)
        end.to raise_error(BuildMusicNetService::PlaylistNotFoundError, /nicht gefunden/)
      end
    end
  end
end
