# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ImportFromSpotify", type: :request do
  fixtures :users

  before { sign_in users(:one) }

  describe "POST /tracks/import_from_spotify" do
    it "reiht ImportAndDownloadSpotifyTrackJob ein und redirected zum Spotify-Tab" do
      allow(ImportAndDownloadSpotifyTrackJob).to receive(:perform_later)

      post import_from_spotify_tracks_path(spotify_track_id: "spotify-track-1")

      aggregate_failures do
        expect(ImportAndDownloadSpotifyTrackJob).to have_received(:perform_later).with("spotify-track-1")
        expect(response).to redirect_to(recently_played_index_tracks_path(tab: "spotify"))
      end
    end

    it "reiht den Job auch dann ein, wenn bereits ein Download läuft - er wartet dort per Mutex#synchronize" do
      allow(ImportAndDownloadSpotifyTrackJob).to receive(:perform_later)
      DownloadPlaylistService::DOWNLOAD_LOCK.lock
      begin
        post import_from_spotify_tracks_path(spotify_track_id: "spotify-track-1")
      ensure
        DownloadPlaylistService::DOWNLOAD_LOCK.unlock
      end

      aggregate_failures do
        expect(ImportAndDownloadSpotifyTrackJob).to have_received(:perform_later).with("spotify-track-1")
        expect(response).to redirect_to(recently_played_index_tracks_path(tab: "spotify"))
      end
    end
  end
end
