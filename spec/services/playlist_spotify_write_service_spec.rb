# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlaylistSpotifyWriteService do
  fixtures :users

  let(:user) { users(:one) }
  let(:spotify_user_id) { "spotify-user-1" }
  let(:service) { described_class.new(user) }

  before do
    spotify_user = double("RSpotify::User", id: spotify_user_id)
    allow(user).to receive(:spotify_user).and_return(spotify_user)
  end

  def stub_spot_playlist(id:, name:, snapshot_id: "snap-#{id}")
    spot_playlist = spotify_playlist(id: id, name: name, owner_id: spotify_user_id, snapshot_id: snapshot_id)
    allow(RSpotify::Playlist).to receive(:find).with(spotify_user_id, id).and_return(spot_playlist)
    spot_playlist
  end

  describe "#rename!" do
    it "pusht den neuen Namen zu Spotify und uebernimmt Name + neue snapshot_id lokal" do
      playlist = Playlist.create!(spotify_id: "pl-1", name: "Alt")
      spot_playlist = stub_spot_playlist(id: "pl-1", name: "Alt")
      renamed = spotify_playlist(id: "pl-1", name: "Neu", owner_id: spotify_user_id, snapshot_id: "snap-neu")
      allow(RSpotify::Playlist).to receive(:find).with(spotify_user_id, "pl-1").and_return(spot_playlist, renamed)
      allow(spot_playlist).to receive(:change_details!)

      service.rename!(playlist, "Neu")

      playlist.reload
      expect(playlist.name).to eq("Neu")
      expect(playlist.snapshot_id).to eq("snap-neu")
    end

    it "berechnet die Bibliothekszuordnung anhand des neuen Namens neu" do
      Library.create!(name: "Fusion", keyword: "fusion")
      playlist = Playlist.create!(spotify_id: "pl-1", name: "Alt")
      spot_playlist = stub_spot_playlist(id: "pl-1", name: "Alt")
      allow(spot_playlist).to receive(:change_details!)

      service.rename!(playlist, "Fusion Night")

      expect(playlist.reload.libraries.map(&:name)).to eq(["Fusion"])
    end

    it "aendert bei einer lokalen Playlist (ohne spotify_id) nur lokal, ohne Spotify-Aufruf" do
      playlist = Playlist.create!(spotify_id: nil, name: "Lokal")
      expect(RSpotify::Playlist).to_not receive(:find)

      service.rename!(playlist, "Lokal Neu")

      expect(playlist.reload.name).to eq("Lokal Neu")
    end

    it "aendert nichts lokal, wenn der Spotify-Push fehlschlaegt" do
      playlist = Playlist.create!(spotify_id: "pl-1", name: "Alt")
      allow(RSpotify::Playlist).to receive(:find).and_raise(RestClient::BadRequest)

      expect { service.rename!(playlist, "Neu") }.to raise_error(SpotifyPlaylistsGateway::SpotifyWriteError)
      expect(playlist.reload.name).to eq("Alt")
    end

    it "wirft SyncAlreadyRunningError, wenn gerade ein Sync laeuft, und aendert nichts lokal" do
      playlist = Playlist.create!(spotify_id: "pl-1", name: "Alt")
      BuildMusicNetService::SYNC_LOCK.lock
      begin
        expect { service.rename!(playlist, "Neu") }.to raise_error(BuildMusicNetService::SyncAlreadyRunningError)
      ensure
        BuildMusicNetService::SYNC_LOCK.unlock
      end
      expect(playlist.reload.name).to eq("Alt")
    end
  end

  describe "#add_track!" do
    let(:album) { Album.create!(spotify_id: "alb-1", name: "Album") }
    let(:track) { Track.create!(spotify_id: "trk-1", name: "Track", album: album) }

    it "pusht den Track zu Spotify und legt lokal die PlaylistTrack-Zeile an" do
      playlist = Playlist.create!(spotify_id: "pl-1", name: "Playlist")
      spot_playlist = stub_spot_playlist(id: "pl-1", name: "Playlist", snapshot_id: "snap-add")
      allow(spot_playlist).to receive(:add_tracks!)

      service.add_track!(playlist, track)

      expect(playlist.tracks.reload).to contain_exactly(track)
      expect(playlist.reload.snapshot_id).to eq("snap-add")
      expect(spot_playlist).to have_received(:add_tracks!).with(["spotify:track:trk-1"])
    end

    it "fuegt bei einer lokalen Playlist nur lokal hinzu, ohne Spotify-Aufruf" do
      playlist = Playlist.create!(spotify_id: nil, name: "Lokal")
      expect(RSpotify::Playlist).to_not receive(:find)

      service.add_track!(playlist, track)

      expect(playlist.tracks.reload).to contain_exactly(track)
    end

    it "legt keine PlaylistTrack-Zeile an, wenn der Spotify-Push fehlschlaegt" do
      playlist = Playlist.create!(spotify_id: "pl-1", name: "Playlist")
      allow(RSpotify::Playlist).to receive(:find).and_raise(RestClient::BadRequest)

      expect { service.add_track!(playlist, track) }.to raise_error(SpotifyPlaylistsGateway::SpotifyWriteError)
      expect(playlist.tracks.reload).to be_empty
    end
  end

  describe "#remove_track!" do
    let(:album) { Album.create!(spotify_id: "alb-1", name: "Album") }
    let(:track) { Track.create!(spotify_id: "trk-1", name: "Track", album: album) }

    it "pusht die Entfernung zu Spotify und loescht lokal die PlaylistTrack-Zeile" do
      playlist = Playlist.create!(spotify_id: "pl-1", name: "Playlist")
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
      spot_playlist = stub_spot_playlist(id: "pl-1", name: "Playlist", snapshot_id: "snap-remove")
      allow(spot_playlist).to receive(:remove_tracks!)

      service.remove_track!(playlist, track)

      expect(playlist.tracks.reload).to be_empty
      expect(playlist.reload.snapshot_id).to eq("snap-remove")
    end

    it "entfernt bei einer lokalen Playlist nur lokal, ohne Spotify-Aufruf" do
      playlist = Playlist.create!(spotify_id: nil, name: "Lokal")
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
      expect(RSpotify::Playlist).to_not receive(:find)

      service.remove_track!(playlist, track)

      expect(playlist.tracks.reload).to be_empty
    end

    it "loescht die PlaylistTrack-Zeile nicht, wenn der Spotify-Push fehlschlaegt" do
      playlist = Playlist.create!(spotify_id: "pl-1", name: "Playlist")
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
      allow(RSpotify::Playlist).to receive(:find).and_raise(RestClient::BadRequest)

      expect { service.remove_track!(playlist, track) }.to raise_error(SpotifyPlaylistsGateway::SpotifyWriteError)
      expect(playlist.tracks.reload).to contain_exactly(track)
    end
  end
end
