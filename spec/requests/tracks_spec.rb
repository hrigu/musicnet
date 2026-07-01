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
  end

  describe "GET /tracks/:id" do
    it "liefert Erfolg" do
      track = create_track

      get track_path(track)

      expect(response).to have_http_status(:success)
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
