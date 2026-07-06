# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Player-Leerzustand (Intent 69)", type: :request do
  fixtures :users

  before { sign_in users(:one) }

  def create_track(name: "Song", spotify_id: "trk1")
    album = Album.create!(name: "Album", spotify_id: "alb-#{spotify_id}")
    Track.create!(name: name, spotify_id: spotify_id, album: album, duration_ms: 200_000)
  end

  it "versteckt Play-Button und Titel-Link des Hauptkanals, wenn die Queue leer ist" do
    get tracks_path

    html = Nokogiri::HTML(response.body)
    toggle_button = html.at_css("[data-audio-player-target='toggleButton']")
    name_link = html.at_css("[data-audio-player-target='name']")

    aggregate_failures do
      expect(toggle_button[:class]).to include("d-none")
      expect(name_link[:class]).to include("d-none")
    end
  end

  it "zeigt Play-Button und Titel-Link des Hauptkanals, wenn die Queue nicht leer ist" do
    track = create_track
    QueueEntry.create!(track: track)

    get tracks_path

    html = Nokogiri::HTML(response.body)
    toggle_button = html.at_css("[data-audio-player-target='toggleButton']")
    name_link = html.at_css("[data-audio-player-target='name']")

    aggregate_failures do
      expect(toggle_button[:class]).to_not include("d-none")
      expect(name_link[:class]).to_not include("d-none")
    end
  end

  it "versteckt Play-Button und Titel-Link des Cue-Kanals immer initial, unabhaengig von der Queue" do
    track = create_track
    QueueEntry.create!(track: track)

    get tracks_path

    html = Nokogiri::HTML(response.body)
    toggle_button = html.at_css("[data-cue-player-target='toggleButton']")
    name_link = html.at_css("[data-cue-player-target='name']")

    aggregate_failures do
      expect(toggle_button[:class]).to include("d-none")
      expect(name_link[:class]).to include("d-none")
    end
  end
end
