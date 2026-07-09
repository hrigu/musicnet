# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImportAndDownloadSpotifyTrackJob, type: :job do
  def build_track
    album = Album.create!(name: "Album job-spotify-1", spotify_id: "alb-job-spotify-1")
    Track.create!(name: "RSpec Job Spotify Import", spotify_id: "job-spotify-1", album:, duration_ms: 200_000)
  end

  it "importiert den Track und laedt ihn herunter" do
    track = build_track
    allow(ImportStandaloneSpotifyTrackService).to receive(:import).with("job-spotify-1").and_return(track)
    download_service = instance_double(DownloadStandaloneTrackService, download: true)
    allow(DownloadStandaloneTrackService).to receive(:new).with(track).and_return(download_service)

    described_class.perform_now("job-spotify-1")

    expect(download_service).to have_received(:download)
  end

  it "broadcastet das Ergebnis ueber den downloads-Kanal" do
    track = build_track
    allow(ImportStandaloneSpotifyTrackService).to receive(:import).and_return(track)
    allow(DownloadStandaloneTrackService).to receive(:new).and_return(instance_double(DownloadStandaloneTrackService, download: true))

    expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).with(
      "downloads", target: "download-log",
                   partial: "tracks/spotify_import_progress_entry", locals: { track: track, success: true }
    )

    described_class.perform_now("job-spotify-1")
  end
end
