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

    it "GET /playlists/:id/download ruft DownloadPlaylistService auf und redirected zur Playlist" do
      service = instance_double(DownloadPlaylistService, download: true)
      allow(DownloadPlaylistService).to receive(:new).and_return(service)
      playlist = playlists(:dark)

      get download_playlist_path(playlist)

      expect(service).to have_received(:download)
      expect(response).to redirect_to(playlist_path(playlist))
    end
  end
end
