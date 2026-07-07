# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PlaylistTracks", type: :request do
  fixtures :users

  let(:album) { Album.create!(spotify_id: "alb-pt-1", name: "Album") }

  def create_track(name:, spotify_id:)
    Track.create!(name: name, spotify_id: spotify_id, album: album, duration_ms: 200_000)
  end

  before { sign_in users(:one) }

  describe "POST /playlist_tracks" do
    it "fuegt den Track ueber den Service zur Playlist hinzu und redirected zur Track-Seite" do
      playlist = Playlist.create!(spotify_id: nil, name: "Ziel-Playlist")
      track = create_track(name: "Song", spotify_id: "pt-1")
      service = instance_double(PlaylistSpotifyWriteService, add_track!: nil)
      allow(PlaylistSpotifyWriteService).to receive(:new).and_return(service)

      post playlist_tracks_path(playlist_id: playlist.id, track_id: track.id)

      expect(service).to have_received(:add_track!).with(playlist, track)
      expect(response).to redirect_to(track_path(track))
      follow_redirect!
      expect(response.body).to include("Ziel-Playlist")
    end

    it "zeigt einen Fehler, wenn der Spotify-Push fehlschlaegt, ohne die Playlist zu aendern" do
      playlist = Playlist.create!(spotify_id: "pl-1", name: "Ziel-Playlist")
      track = create_track(name: "Song", spotify_id: "pt-2")
      service = instance_double(PlaylistSpotifyWriteService)
      allow(service).to receive(:add_track!).and_raise(SpotifyPlaylistsGateway::SpotifyWriteError, "Spotify nicht erreichbar")
      allow(PlaylistSpotifyWriteService).to receive(:new).and_return(service)

      post playlist_tracks_path(playlist_id: playlist.id, track_id: track.id)

      expect(response).to redirect_to(track_path(track))
      follow_redirect!
      expect(response.body).to include("Spotify nicht erreichbar")
      expect(playlist.tracks.reload).to be_empty
    end
  end

  describe "DELETE /playlist_tracks/:id" do
    it "entfernt den Track ueber den Service und redirected zur Track-Seite" do
      playlist = Playlist.create!(spotify_id: nil, name: "Quell-Playlist")
      track = create_track(name: "Song", spotify_id: "pt-3")
      playlist_track = PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
      service = instance_double(PlaylistSpotifyWriteService, remove_track!: nil)
      allow(PlaylistSpotifyWriteService).to receive(:new).and_return(service)

      delete playlist_track_path(playlist_track)

      expect(service).to have_received(:remove_track!).with(playlist, track)
      expect(response).to redirect_to(track_path(track))
    end

    it "zeigt einen Fehler, wenn der Spotify-Push fehlschlaegt, ohne die Zuordnung zu loeschen" do
      playlist = Playlist.create!(spotify_id: "pl-1", name: "Quell-Playlist")
      track = create_track(name: "Song", spotify_id: "pt-4")
      playlist_track = PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
      service = instance_double(PlaylistSpotifyWriteService)
      allow(service).to receive(:remove_track!)
        .and_raise(BuildMusicNetService::SyncAlreadyRunningError, "Es läuft bereits ein Sync - bitte warten, bis er fertig ist")
      allow(PlaylistSpotifyWriteService).to receive(:new).and_return(service)

      delete playlist_track_path(playlist_track)

      expect(response).to redirect_to(track_path(track))
      follow_redirect!
      expect(response.body).to include("läuft bereits ein Sync")
      expect(playlist.tracks.reload).to contain_exactly(track)
    end
  end
end
