# frozen_string_literal: true

require "rails_helper"

RSpec.describe ResolveDjSessionPlaybackLocationJob, type: :job do
  def create_playback(latitude: nil, longitude: nil)
    user = User.create!(email: "rspec-location-job-#{SecureRandom.hex(4)}@example.com", password: "password123")
    album = Album.create!(name: "Album loc-job-#{SecureRandom.hex(4)}", spotify_id: "alb-loc-job-#{SecureRandom.hex(4)}")
    track = Track.create!(name: "RSpec Location Job", spotify_id: "loc-job-#{SecureRandom.hex(4)}", album:,
                          duration_ms: 200_000)
    DjSessionPlayback.create!(user:, track:, played_at: Time.current, latitude:, longitude:)
  end

  it "speichert den aufgeloesten Ortsnamen am Playback" do
    playback = create_playback(latitude: 47.376887, longitude: 8.541694)
    allow(LocationNameResolver).to receive(:resolve).with(latitude: 47.376887, longitude: 8.541694).and_return("Zürich")

    described_class.perform_now(playback)

    expect(playback.reload.location_name).to eq("Zürich")
  end

  it "lässt location_name unveraendert, wenn die Aufloesung nichts liefert" do
    playback = create_playback(latitude: 47.376887, longitude: 8.541694)
    allow(LocationNameResolver).to receive(:resolve).and_return(nil)

    described_class.perform_now(playback)

    expect(playback.reload.location_name).to be_nil
  end

  it "ruft den Resolver gar nicht auf, wenn keine Koordinaten vorhanden sind" do
    playback = create_playback

    expect(LocationNameResolver).not_to receive(:resolve)

    described_class.perform_now(playback)
  end
end
