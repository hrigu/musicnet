# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tracks", type: :request do
  fixtures :users

  let(:downloads_dir) { Rails.root.join("downloads/tracks") }

  def create_track(name: "Song", spotify_id: "trk1")
    album = Album.create!(name: "Album", spotify_id: "alb-#{spotify_id}")
    Track.create!(name: name, spotify_id: spotify_id, album: album, duration_ms: 200_000)
  end

  def with_download_file(file_name)
    FileUtils.mkdir_p(downloads_dir)
    FileUtils.touch(downloads_dir.join(file_name))
    yield
  ensure
    FileUtils.rm_f(downloads_dir.join(file_name))
  end

  before do
    sign_in users(:one)
  end

  describe "GET /tracks" do
    it "liefert Erfolg" do
      create_track

      get tracks_path

      expect(response).to have_http_status(:success)
    end

    it "zeigt ein Badge statt des Players für Tracks ohne Soundfile" do
      create_track

      get tracks_path

      aggregate_failures do
        expect(response.body).to include("kein File")
        expect(response.body).to_not include("<audio")
      end
    end

    it "zeigt den Player für Tracks mit Soundfile" do
      create_track

      with_download_file("RSpec Artist - Song.m4a") do
        get tracks_path
      end

      aggregate_failures do
        expect(response.body).to include("<audio")
        expect(response.body).to_not include("kein File")
      end
    end

    it "zeigt die Playlist-Badges ohne eine Query pro Track" do
      playlist = Playlist.create!(spotify_id: "pl-q1", name: "Fusion Badge")
      other_playlist = Playlist.create!(spotify_id: "pl-q2", name: "Blues Badge")
      3.times do |i|
        track = create_track(name: "Track #{i}", spotify_id: "trk-q#{i}")
        PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
        PlaylistTrack.create!(playlist: other_playlist, track: track, added_at: Time.current)
      end

      queries = []
      callback = lambda do |_name, _start, _finish, _id, payload|
        queries << payload[:sql] unless payload[:name] == "SCHEMA"
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get tracks_path
      end

      expect(response).to have_http_status(:success)
      aggregate_failures do
        expect(queries.count { |sql| sql.include?('FROM "playlist_tracks"') }).to eq(1)
        expect(queries.count { |sql| sql.include?('FROM "playlists"') }).to eq(1)
        expect(response.body).to include("F_Badge")
        expect(response.body).to include("B_Badge")
      end
    end
  end

  describe "GET /tracks/:id" do
    it "liefert Erfolg" do
      track = create_track

      get track_path(track)

      expect(response).to have_http_status(:success)
    end

    it "rendert die Playlist-Zeile inkl. Track-Anzahl, wenn der Track in einer Playlist ist" do
      track = create_track
      playlist = Playlist.create!(spotify_id: "pl-t1", name: "Fusion Badge")
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)

      get track_path(track)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("<td>1</td>")
    end
  end

  describe "GET / (recently_played_index)" do
    it "verwendet den angemeldeten User für recently_played" do
      current_spotify_user = users(:one).spotify_user
      other_spotify_user = users(:two).spotify_user
      allow(current_spotify_user).to receive(:recently_played).with(limit: 50).and_return([])
      expect(other_spotify_user).not_to receive(:recently_played)

      get root_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /tracks/download" do
    it "ruft DownloadTrackService auf und redirected zu tracks_path" do
      service = instance_double(DownloadTrackService, download: true)
      allow(DownloadTrackService).to receive(:new).and_return(service)

      get download_tracks_path

      expect(service).to have_received(:download)
      expect(response).to redirect_to(tracks_path)
    end

    it "zeigt einen Alert, wenn bereits ein Download läuft" do
      service = instance_double(DownloadTrackService)
      allow(service).to receive(:download)
        .and_raise(DownloadPlaylistService::DownloadAlreadyRunningError, "Es läuft bereits ein Download")
      allow(DownloadTrackService).to receive(:new).and_return(service)

      get download_tracks_path

      expect(response).to redirect_to(tracks_path)
      expect(flash[:alert]).to include("läuft bereits")
    end
  end

  describe "GET /tracks/:id/stream" do
    it "sendet die Datei, wenn track_path vorhanden ist" do
      track = create_track

      with_download_file("RSpec Artist - Song.m4a") do
        get stream_track_path(track)
      end

      expect(response).to have_http_status(:success)
    end
  end
end
