# frozen_string_literal: true

require "rails_helper"

RSpec.describe DownloadStandaloneTrackService do
  def build_track(url: "https://open.spotify.com/track/standalone-dl-1", spotify_id: "standalone-dl-1")
    album = Album.create!(name: "Album #{spotify_id}", spotify_id: "alb-#{spotify_id}")
    Track.create!(name: "RSpec Standalone Download", spotify_id:, album:, duration_ms: 200_000, url:)
  end

  def stub_audio_features_extraction
    extraction = instance_double(AudioFeaturesExtractionService, extract_missing: nil)
    allow(AudioFeaturesExtractionService).to receive(:new).and_return(extraction)
    extraction
  end

  before { stub_audio_features_extraction }

  it "ruft system mit dem korrekten spotdl-download-Kommando fuer track.url auf" do
    track = build_track
    service = described_class.new(track)
    allow(service).to receive(:system).and_return(true)

    service.download

    expect(service).to have_received(:system).with(
      "spotdl download https://open.spotify.com/track/standalone-dl-1 --format m4a --audio youtube bandcamp --simple-tui",
      chdir: Rails.root.join("downloads/tracks")
    )
  end

  it "baut die Track-URL aus spotify_id, wenn track.url fehlt" do
    track = build_track(url: nil, spotify_id: "standalone-dl-2")
    service = described_class.new(track)
    allow(service).to receive(:system).and_return(true)

    service.download

    expect(service).to have_received(:system).with(
      "spotdl download https://open.spotify.com/track/standalone-dl-2 --format m4a --audio youtube bandcamp --simple-tui",
      chdir: Rails.root.join("downloads/tracks")
    )
  end

  it "teilt sich den DOWNLOAD_LOCK mit DownloadPlaylistService" do
    track = build_track
    service = described_class.new(track)
    allow(service).to receive(:system) do
      expect(DownloadPlaylistService::DOWNLOAD_LOCK).to be_locked
      true
    end

    service.download

    expect(DownloadPlaylistService::DOWNLOAD_LOCK).to_not be_locked
  end

  it "ruft nach erfolgreichem Download die Audio-Feature-Extraktion fuer genau diesen Track auf" do
    track = build_track
    service = described_class.new(track)
    allow(service).to receive(:system).and_return(true)
    extraction = instance_double(AudioFeaturesExtractionService, extract_missing: nil)
    allow(AudioFeaturesExtractionService).to receive(:new).with([track]).and_return(extraction)

    service.download

    expect(extraction).to have_received(:extract_missing)
  end

  it "ruft die Audio-Feature-Extraktion nicht auf, wenn der Download fehlschlaegt" do
    track = build_track
    service = described_class.new(track)
    allow(service).to receive(:system).and_return(false)

    service.download

    expect(AudioFeaturesExtractionService).to_not have_received(:new)
  end

  it "gibt false zurueck, wenn der Download fehlschlaegt" do
    track = build_track
    service = described_class.new(track)
    allow(service).to receive(:system).and_return(false)

    expect(service.download).to be(false)
  end

  it "gibt true zurueck, wenn nach dem Download eine Datei gefunden wird" do
    track = build_track
    FileUtils.mkdir_p(Rails.root.join("downloads/tracks"))
    file_path = Rails.root.join("downloads/tracks/RSpec Artist - RSpec Standalone Download.m4a")
    FileUtils.touch(file_path)
    service = described_class.new(track)
    allow(service).to receive(:system).and_return(true)

    begin
      expect(service.download).to be(true)
    ensure
      FileUtils.rm_f(file_path)
    end
  end

  it "speichert file_name in der DB, wenn nach dem Download eine Datei gefunden wird" do
    track = build_track
    FileUtils.mkdir_p(Rails.root.join("downloads/tracks"))
    file_path = Rails.root.join("downloads/tracks/RSpec Artist - RSpec Standalone Download.m4a")
    FileUtils.touch(file_path)
    service = described_class.new(track)
    allow(service).to receive(:system).and_return(true)

    begin
      service.download
      expect(track.reload.file_name).to eq("RSpec Artist - RSpec Standalone Download.m4a")
    ensure
      FileUtils.rm_f(file_path)
    end
  end

  it "speichert kein file_name, wenn der Download fehlschlaegt" do
    track = build_track
    service = described_class.new(track)
    allow(service).to receive(:system).and_return(false)

    service.download

    expect(track.reload.file_name).to be_nil
  end
end
