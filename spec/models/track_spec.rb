# frozen_string_literal: true

require "rails_helper"

RSpec.describe Track, type: :model do
  describe "#dauer" do
    it "formatiert duration_ms als MM:SS" do
      track = Track.new(duration_ms: 125_000)

      expect(track.dauer).to eq("02:05")
    end
  end

  describe "#af, #energy, #tempo" do
    it "parst audio_features in ein OpenStruct" do
      track = Track.new(audio_features: { energy: 0.7, tempo: 120.5 }.to_json)

      expect(track.energy).to eq(0.7)
      expect(track.tempo).to eq(120.5)
    end

    it "gibt nil zurück, wenn audio_features leer ist" do
      track = Track.new(audio_features: nil)

      expect(track.af).to be_nil
      expect(track.energy).to be_nil
      expect(track.tempo).to be_nil
    end
  end

  describe "#track_path" do
    it "findet die passende, sanitisierte Datei im downloads/tracks-Verzeichnis" do
      track = Track.new(name: "Song: Live")
      allow(Dir).to receive(:chdir).and_yield
      allow(Dir).to receive(:glob).with("*-?Song- Live.m4a").and_return(["01-Song- Live.m4a"])

      expect(track.track_path).to eq("01-Song- Live.m4a")
    end

    it "gibt nil zurück, wenn keine Datei gefunden wird" do
      track = Track.new(name: "Unbekannter Song")
      allow(Dir).to receive(:chdir).and_yield
      allow(Dir).to receive(:glob).and_return([])

      expect(track.track_path).to be_nil
    end
  end

  describe "#genre" do
    it "gibt nil zurück, wenn kein Track-File gefunden wird" do
      track = Track.new(name: "Unbekannter Song")
      allow(Dir).to receive(:chdir).and_yield
      allow(Dir).to receive(:glob).and_return([])

      expect(track.genre).to be_nil
    end
  end
end
