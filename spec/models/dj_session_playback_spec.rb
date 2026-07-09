# frozen_string_literal: true

require "rails_helper"

RSpec.describe DjSessionPlayback, type: :model do
  def create_track(name:, spotify_id:)
    album = Album.create!(name: "Album #{spotify_id}", spotify_id: "alb-#{spotify_id}")
    Track.create!(name:, spotify_id:, album:, duration_ms: 200_000)
  end

  it "verlangt User, Track und played_at" do
    playback = described_class.new

    expect(playback).not_to be_valid
    expect(playback.errors[:user]).to be_present
    expect(playback.errors[:track]).to be_present
    expect(playback.errors[:played_at]).to be_present
  end

  it "erlaubt Playback-Eintraege ohne Ortsdaten" do
    user = User.create!(email: "rspec-playback@example.com", password: "password123")
    track = create_track(name: "RSpec Playback", spotify_id: "rspec-playback-1")

    playback = described_class.new(user:, track:, played_at: Time.zone.parse("2026-07-09 21:15:00"))

    expect(playback).to be_valid
  end

  it "speichert optionale Ortsdaten mit" do
    user = User.create!(email: "rspec-playback-location@example.com", password: "password123")
    track = create_track(name: "RSpec Playback Ort", spotify_id: "rspec-playback-2")

    playback = described_class.create!(
      user:,
      track:,
      played_at: Time.zone.parse("2026-07-09 22:15:00"),
      latitude: 47.376887,
      longitude: 8.541694,
      location_accuracy_meters: 18.5
    )

    aggregate_failures do
      expect(playback.latitude.to_f).to eq(47.376887)
      expect(playback.longitude.to_f).to eq(8.541694)
      expect(playback.location_accuracy_meters.to_f).to eq(18.5)
    end
  end

  describe ".recent_first" do
    it "sortiert nach played_at absteigend" do
      user = User.create!(email: "rspec-playback-sort@example.com", password: "password123")
      older_track = create_track(name: "RSpec Playback Alt", spotify_id: "rspec-playback-3")
      newer_track = create_track(name: "RSpec Playback Neu", spotify_id: "rspec-playback-4")
      older = described_class.create!(user:, track: older_track, played_at: Time.zone.parse("2026-07-09 20:00:00"))
      newer = described_class.create!(user:, track: newer_track, played_at: Time.zone.parse("2026-07-09 23:00:00"))

      expect(described_class.recent_first).to eq([newer, older])
    end
  end
end
