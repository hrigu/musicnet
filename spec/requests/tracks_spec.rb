# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tracks", type: :request do
  fixtures :users

  def create_track(name: "Song", spotify_id: "trk1")
    album = Album.create!(name: "Album", spotify_id: "alb-#{spotify_id}")
    Track.create!(name: name, spotify_id: spotify_id, album: album, duration_ms: 200_000)
  end

  before do
    sign_in users(:one)
    allow_any_instance_of(Track).to receive(:track_path).and_return(nil)
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
      existing_file = Rails.root.join("spec/fixtures/files/.keep").to_s
      allow_any_instance_of(Track).to receive(:track_path).and_return(existing_file)

      get tracks_path

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
    it "liefert Erfolg" do
      spotify_user = double("RSpotify::User", recently_played: [],
                                               images: [{ "url" => "https://example.com/avatar.png" }])
      allow_any_instance_of(User).to receive(:spotify_user).and_return(spotify_user)

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
      existing_file = Rails.root.join("spec/fixtures/files/.keep").to_s
      allow_any_instance_of(Track).to receive(:track_path).and_return(existing_file)

      get stream_track_path(track)

      expect(response).to have_http_status(:success)
    end
  end
end
