# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Playlists", type: :request do
  fixtures :users, :playlists

  describe "ohne Login" do
    it "redirected zum Sign-in" do
      get playlists_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "mit Login" do
    before { sign_in users(:one) }

    it "GET /playlists liefert Erfolg" do
      get playlists_path

      expect(response).to have_http_status(:success)
    end

    it "GET /playlists zeigt die Track-Anzahl ohne eine COUNT-Query pro Playlist" do
      album = Album.create!(spotify_id: "alb-i1", name: "A Go Go")
      with_two = Playlist.create!(spotify_id: "pl-i1", name: "Fusion Zwei")
      Playlist.create!(spotify_id: "pl-i2", name: "Fusion Leer")
      2.times do |i|
        track = Track.create!(spotify_id: "trk-i#{i}", name: "Track #{i}", album: album, duration_ms: 200_000)
        PlaylistTrack.create!(playlist: with_two, track: track, added_at: Time.current)
      end

      queries = []
      callback = lambda do |_name, _start, _finish, _id, payload|
        queries << payload[:sql] unless payload[:name] == "SCHEMA"
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get playlists_path
      end

      expect(response).to have_http_status(:success)
      aggregate_failures do
        expect(queries.count { |sql| sql.include?('FROM "tracks"') }).to eq(0)
        expect(response.body).to include("<td>2</td>")
        expect(response.body).to include("<td>0</td>")
      end
    end

    it "GET /playlists/:id liefert Erfolg" do
      get playlist_path(playlists(:dark))

      expect(response).to have_http_status(:success)
    end

    it "GET /playlists/fetch_all ruft BuildMusicNetService auf und liefert Erfolg" do
      info = BuildMusicNetService::ServiceInfo.new
      service = instance_double(BuildMusicNetService, build: info)
      allow(BuildMusicNetService).to receive(:new).and_return(service)

      get fetch_all_playlists_path

      expect(response).to have_http_status(:success)
      expect(service).to have_received(:build)
    end

    it "GET /playlists/:id lädt tracks, artists und albums mit je genau einer Query" do
      album = Album.create!(spotify_id: "alb-n1", name: "A Go Go")
      artist = Artist.create!(spotify_id: "art-n1", name: "John Scofield")
      playlist = Playlist.create!(spotify_id: "pl-n1", name: "Fusion Query")
      other_playlist = Playlist.create!(spotify_id: "pl-n2", name: "Blues Query")
      3.times do |i|
        track = Track.create!(spotify_id: "trk-n#{i}", name: "Track #{i}", album: album,
                              artists: [artist], duration_ms: 200_000)
        PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
        PlaylistTrack.create!(playlist: other_playlist, track: track, added_at: Time.current)
      end

      queries = []
      callback = lambda do |_name, _start, _finish, _id, payload|
        queries << payload[:sql] unless payload[:name] == "SCHEMA"
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get playlist_path(playlist)
      end

      expect(response).to have_http_status(:success)
      aggregate_failures do
        expect(queries.count { |sql| sql.include?('FROM "tracks"') }).to eq(1)
        expect(queries.count { |sql| sql.include?('FROM "artists"') }).to eq(1)
        expect(queries.count { |sql| sql.include?('FROM "albums"') }).to eq(1)
      end
    end

    it "GET /playlists/:id lädt Audio-Elemente nicht automatisch (preload=none)" do
      album = Album.create!(spotify_id: "alb-p1", name: "A Go Go")
      playlist = Playlist.create!(spotify_id: "pl-p1", name: "Fusion Preload")
      track = Track.create!(spotify_id: "trk-p1", name: "Hottentot", album: album, duration_ms: 200_000)
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
      existing_file = Rails.root.join("spec/fixtures/files/.keep").to_s
      allow_any_instance_of(Track).to receive(:track_path).and_return(existing_file)

      get playlist_path(playlist)

      expect(response.body).to include('preload="none"')
      expect(response.body).to_not include('preload="false"')
    end

    it "GET /playlists/:id zeigt das Badge für Tracks ohne Soundfile" do
      album = Album.create!(spotify_id: "alb-b1", name: "A Go Go")
      playlist = Playlist.create!(spotify_id: "pl-b1", name: "Fusion Badge")
      track = Track.create!(spotify_id: "trk-b1", name: "RSpec Ohne File", album: album, duration_ms: 200_000)
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)

      get playlist_path(playlist)

      aggregate_failures do
        expect(response.body).to include("kein File")
        expect(response.body).to_not include("<audio")
      end
    end

    it "GET /playlists/:id löst die Track-Pfade mit einem einzigen Verzeichnis-Scan auf" do
      album = Album.create!(spotify_id: "alb-s1", name: "A Go Go")
      playlist = Playlist.create!(spotify_id: "pl-s1", name: "Fusion Scan")
      3.times do |i|
        track = Track.create!(spotify_id: "trk-s#{i}", name: "RSpec Scan #{i}", album: album, duration_ms: 200_000)
        PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
      end
      allow(Dir).to receive(:children).and_call_original

      get playlist_path(playlist)

      expect(Dir).to have_received(:children).with(Track.downloads_dir).at_most(:once)
    end

    it "GET /playlists/:id zeigt den Button zum Aktualisieren der Playlist" do
      playlist = playlists(:dark)

      get playlist_path(playlist)

      expect(response.body).to include(refresh_playlist_path(playlist))
      expect(response.body).to include("Playlist aktualisieren")
    end

    it "GET /playlists/:id/refresh ruft refresh_playlist auf und rendert die Playlist-Seite" do
      info = BuildMusicNetService::RefreshInfo.new(["Green Tea"], ["Hottentot"])
      service = instance_double(BuildMusicNetService, refresh_playlist: info)
      allow(BuildMusicNetService).to receive(:new).and_return(service)
      playlist = playlists(:dark)

      get refresh_playlist_path(playlist)

      expect(response).to have_http_status(:success)
      expect(service).to have_received(:refresh_playlist).with(playlist)
      expect(response.body).to include("Green Tea")
      expect(response.body).to include("Hottentot")
    end

    it "GET /playlists/:id/refresh zeigt einen Hinweis, wenn es keine Änderungen gibt" do
      info = BuildMusicNetService::RefreshInfo.new([], [])
      service = instance_double(BuildMusicNetService, refresh_playlist: info)
      allow(BuildMusicNetService).to receive(:new).and_return(service)

      get refresh_playlist_path(playlists(:dark))

      expect(response.body).to include("Keine Änderungen")
    end

    it "GET /playlists/:id/refresh zeigt bei nicht mehr existierender Spotify-Playlist einen Alert" do
      service = instance_double(BuildMusicNetService)
      allow(service).to receive(:refresh_playlist)
        .and_raise(BuildMusicNetService::PlaylistNotFoundError, "Playlist 'Fusion Dark' wurde auf Spotify nicht gefunden")
      allow(BuildMusicNetService).to receive(:new).and_return(service)
      playlist = playlists(:dark)

      get refresh_playlist_path(playlist)

      expect(response).to redirect_to(playlist_path(playlist))
      expect(flash[:alert]).to include("nicht gefunden")
    end

    it "GET /playlists/fetch_all zeigt einen Alert, wenn bereits ein Sync läuft" do
      service = instance_double(BuildMusicNetService)
      allow(service).to receive(:build)
        .and_raise(BuildMusicNetService::SyncAlreadyRunningError, "Es läuft bereits ein Sync")
      allow(BuildMusicNetService).to receive(:new).and_return(service)

      get fetch_all_playlists_path

      expect(response).to redirect_to(playlists_path)
      expect(flash[:alert]).to include("läuft bereits")
    end

    it "GET /playlists/:id/refresh zeigt einen Alert, wenn bereits ein Sync läuft" do
      service = instance_double(BuildMusicNetService)
      allow(service).to receive(:refresh_playlist)
        .and_raise(BuildMusicNetService::SyncAlreadyRunningError, "Es läuft bereits ein Sync")
      allow(BuildMusicNetService).to receive(:new).and_return(service)
      playlist = playlists(:dark)

      get refresh_playlist_path(playlist)

      expect(response).to redirect_to(playlist_path(playlist))
      expect(flash[:alert]).to include("läuft bereits")
    end

    it "GET /playlists/:id/download ruft DownloadPlaylistService auf und redirected zur Playlist" do
      service = instance_double(DownloadPlaylistService, download: true)
      allow(DownloadPlaylistService).to receive(:new).and_return(service)
      playlist = playlists(:dark)

      get download_playlist_path(playlist)

      expect(service).to have_received(:download)
      expect(response).to redirect_to(playlist_path(playlist))
    end

    it "GET /playlists/:id/download zeigt einen Alert, wenn bereits ein Download läuft" do
      service = instance_double(DownloadPlaylistService)
      allow(service).to receive(:download)
        .and_raise(DownloadPlaylistService::DownloadAlreadyRunningError, "Es läuft bereits ein Download")
      allow(DownloadPlaylistService).to receive(:new).and_return(service)
      playlist = playlists(:dark)

      get download_playlist_path(playlist)

      expect(response).to redirect_to(playlist_path(playlist))
      expect(flash[:alert]).to include("läuft bereits")
    end
  end
end
