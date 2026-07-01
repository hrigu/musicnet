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
end
