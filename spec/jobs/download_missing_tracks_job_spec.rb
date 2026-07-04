# frozen_string_literal: true

require "rails_helper"

RSpec.describe DownloadMissingTracksJob do
  describe "#perform" do
    let(:album) { Album.create!(spotify_id: "alb1", name: "A Go Go") }
    let(:fusion) { Playlist.create!(spotify_id: "pl1", name: "Fusion One") }
    let(:blues) { Playlist.create!(spotify_id: "pl2", name: "Blues Two") }
    let(:track_one) { Track.create!(spotify_id: "trk1", name: "Hottentot", album: album) }
    let(:track_two) { Track.create!(spotify_id: "trk2", name: "Green Tea", album: album) }
    let(:track_three) { Track.create!(spotify_id: "trk3", name: "Chank", album: album) }

    def stub_playlist_sync
      sync = instance_double(DownloadPlaylistService, download: nil)
      allow(DownloadPlaylistService).to receive(:new).and_return(sync)
      sync
    end

    it "führt pro betroffener Playlist genau einen Playlist-Sync aus" do
      PlaylistTrack.create!(playlist: fusion, track: track_one)
      PlaylistTrack.create!(playlist: fusion, track: track_two)
      PlaylistTrack.create!(playlist: blues, track: track_three)
      sync = stub_playlist_sync

      described_class.new.perform([track_one, track_two, track_three])

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

      described_class.new.perform([track_one, track_two])

      expect(DownloadPlaylistService).to have_received(:new).twice
      expect(sync).to have_received(:download).twice
    end

    it "macht ohne Tracks gar nichts" do
      stub_playlist_sync

      described_class.new.perform([])

      expect(DownloadPlaylistService).to_not have_received(:new)
    end
  end

  describe "Live-Feedback per Turbo Streams" do
    let(:album) { Album.create!(spotify_id: "alb-lf1", name: "A Go Go") }
    let(:fusion) { Playlist.create!(spotify_id: "pl-lf1", name: "Fusion One") }
    let(:track_one) { Track.create!(spotify_id: "trk-lf1", name: "Hottentot", album: album) }

    before { allow(Turbo::StreamsChannel).to receive(:broadcast_append_to) }

    it "broadcastet nach jeder fertigen Playlist eine Ergebnis-Zeile" do
      PlaylistTrack.create!(playlist: fusion, track: track_one)
      result = DownloadResultParser::Result.new([{ name: "Hottentot", provider: "YouTube" }], [])
      allow(DownloadPlaylistService).to receive(:new).and_return(instance_double(DownloadPlaylistService,
                                                                                 download: result))

      described_class.new.perform([track_one])

      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with(
        "downloads", target: "download-log", partial: "tracks/download_progress_entry",
                     locals: { playlist: fusion, result: result }
      )
    end

    it "broadcastet nichts fuer eine Playlist, wenn der Download fehlschlaegt (kein Ergebnis)" do
      PlaylistTrack.create!(playlist: fusion, track: track_one)
      allow(DownloadPlaylistService).to receive(:new).and_return(instance_double(DownloadPlaylistService,
                                                                                 download: nil))

      described_class.new.perform([track_one])

      expect(Turbo::StreamsChannel).to_not have_received(:broadcast_append_to).with("downloads",
                                                                                    hash_including(partial: anything))
    end

    it "broadcastet zum Schluss eine Abschluss-Meldung" do
      PlaylistTrack.create!(playlist: fusion, track: track_one)
      result = DownloadResultParser::Result.new([], [])
      allow(DownloadPlaylistService).to receive(:new).and_return(instance_double(DownloadPlaylistService,
                                                                                 download: result))

      described_class.new.perform([track_one])

      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with(
        "downloads", target: "download-log", html: "<div>Fertig.</div>"
      )
    end
  end
end
