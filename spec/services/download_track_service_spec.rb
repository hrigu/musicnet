# frozen_string_literal: true

require "rails_helper"

RSpec.describe DownloadTrackService do
  describe "#download" do
    let(:album) { Album.create!(spotify_id: "alb1", name: "A Go Go") }
    let(:fusion) { Playlist.create!(spotify_id: "pl1", name: "Fusion One") }
    let(:blues) { Playlist.create!(spotify_id: "pl2", name: "Blues Two") }
    let(:track_one) { Track.create!(spotify_id: "trk1", name: "Hottentot", album: album) }
    let(:track_two) { Track.create!(spotify_id: "trk2", name: "Green Tea", album: album) }
    let(:track_three) { Track.create!(spotify_id: "trk3", name: "Chank", album: album) }

    def stub_playlist_sync
      sync = instance_double(DownloadPlaylistService, download: true)
      allow(DownloadPlaylistService).to receive(:new).and_return(sync)
      sync
    end

    it "führt pro betroffener Playlist genau einen Playlist-Sync aus" do
      PlaylistTrack.create!(playlist: fusion, track: track_one)
      PlaylistTrack.create!(playlist: fusion, track: track_two)
      PlaylistTrack.create!(playlist: blues, track: track_three)
      sync = stub_playlist_sync

      described_class.new([track_one, track_two, track_three]).download

      aggregate_failures do
        expect(DownloadPlaylistService).to have_received(:new).with(fusion).once
        expect(DownloadPlaylistService).to have_received(:new).with(blues).once
        expect(sync).to have_received(:download).twice
      end
    end

    it "synct eine Playlist nur einmal, auch wenn ein Track in mehreren Playlists liegt" do
      PlaylistTrack.create!(playlist: fusion, track: track_one)
      PlaylistTrack.create!(playlist: blues, track: track_one)
      PlaylistTrack.create!(playlist: fusion, track: track_two)
      sync = stub_playlist_sync

      described_class.new([track_one, track_two]).download

      expect(DownloadPlaylistService).to have_received(:new).twice
      expect(sync).to have_received(:download).twice
    end

    it "macht ohne Tracks gar nichts" do
      stub_playlist_sync

      described_class.new([]).download

      expect(DownloadPlaylistService).to_not have_received(:new)
    end
  end
end
