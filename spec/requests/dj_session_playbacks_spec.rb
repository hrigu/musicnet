# frozen_string_literal: true

require "rails_helper"

RSpec.describe "DjSessionPlaybacks", type: :request do
  fixtures :users

  before { sign_in users(:one) }

  def create_track(spotify_id: "rspec-dsp-1", name: "RSpec Playback Track")
    album = Album.create!(name: "Album #{spotify_id}", spotify_id: "alb-#{spotify_id}")
    Track.create!(name:, spotify_id:, album:, duration_ms: 200_000)
  end

  describe "POST /dj_session_playbacks" do
    it "speichert lokales Playback fuer aktuellen User und Track" do
      track = create_track

      expect do
        post dj_session_playbacks_path, params: { dj_session_playback: { track_id: track.id } }, as: :json
      end.to change(DjSessionPlayback, :count).by(1)

      playback = DjSessionPlayback.last
      aggregate_failures do
        expect(response).to have_http_status(:created)
        expect(playback.user).to eq(users(:one))
        expect(playback.track).to eq(track)
        expect(playback.played_at).to be_within(5.seconds).of(Time.current)
      end
    end

    it "funktioniert ohne Ortsdaten" do
      track = create_track(spotify_id: "rspec-dsp-2")

      post dj_session_playbacks_path, params: { dj_session_playback: { track_id: track.id } }, as: :json

      playback = DjSessionPlayback.last
      aggregate_failures do
        expect(response).to have_http_status(:created)
        expect(playback.latitude).to be_nil
        expect(playback.longitude).to be_nil
        expect(playback.location_accuracy_meters).to be_nil
      end
    end

    it "speichert gelieferte Ortsdaten mit" do
      track = create_track(spotify_id: "rspec-dsp-3")

      post dj_session_playbacks_path,
           params: {
             dj_session_playback: {
               track_id: track.id,
               latitude: 47.376887,
               longitude: 8.541694,
               location_accuracy_meters: 12.25
             }
           }, as: :json

      playback = DjSessionPlayback.last
      aggregate_failures do
        expect(response).to have_http_status(:created)
        expect(playback.latitude.to_f).to eq(47.376887)
        expect(playback.longitude.to_f).to eq(8.541694)
        expect(playback.location_accuracy_meters.to_f).to eq(12.25)
      end
    end
  end
end
