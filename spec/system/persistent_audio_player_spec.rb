# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dauerhafte Track-Wiedergabe (Intent 40)", type: :system do
  fixtures :users

  let(:album) { Album.create!(spotify_id: "alb-player-1", name: "Album") }
  let(:downloads_dir) { Rails.root.join("downloads/tracks") }

  def create_playable_track(name, spotify_id:)
    track = Track.create!(name: name, spotify_id: spotify_id, album: album, duration_ms: 200_000)
    FileUtils.mkdir_p(downloads_dir)
    FileUtils.touch(downloads_dir.join("RSpec Artist - #{name}.m4a"))
    track
  end

  def play_button_for(track_name)
    page.find("tr", text: track_name).find("button")
  end

  after do
    Dir.glob(downloads_dir.join("RSpec Artist - *.m4a")).each { |f| FileUtils.rm_f(f) }
  end

  before { login_as(users(:one), scope: :user) }

  it "ueberlebt eine Suche auf /tracks (Turbo-Frame-Update)" do
    track = create_playable_track("System Spec Alpha", spotify_id: "sys-alpha")

    visit tracks_path
    play_button_for(track.name).click
    expect(page).to have_selector("#global-audio-player", text: track.name)
    page.execute_script("document.getElementById('global-audio-player').dataset.marker = 'still-here'")

    fill_in "q", with: track.name
    click_button "Suchen"

    expect(page).to have_selector("table", text: track.name)
    marker = page.evaluate_script("document.getElementById('global-audio-player').dataset.marker")
    expect(marker).to eq("still-here")
  end

  it "ueberlebt einen Seitenwechsel dank data-turbo-permanent" do
    track = create_playable_track("System Spec Beta", spotify_id: "sys-beta")

    visit tracks_path
    play_button_for(track.name).click
    expect(page).to have_selector("#global-audio-player", text: track.name)
    page.execute_script("document.getElementById('global-audio-player').dataset.marker = 'still-here'")

    click_link "Playlists"

    expect(page).to have_content("Meine Playlists")
    marker = page.evaluate_script(
      "document.getElementById('global-audio-player') && document.getElementById('global-audio-player').dataset.marker"
    )
    expect(marker).to eq("still-here")
  end

  it "wechselt zum neuen Track, wenn ein anderer Play-Button geklickt wird" do
    track_a = create_playable_track("System Spec Gamma", spotify_id: "sys-gamma")
    track_b = create_playable_track("System Spec Delta", spotify_id: "sys-delta")

    visit tracks_path
    play_button_for(track_a.name).click
    expect(page).to have_selector("#global-audio-player", text: track_a.name)

    play_button_for(track_b.name).click

    aggregate_failures do
      expect(page).to have_selector("#global-audio-player", text: track_b.name)
      expect(page).to_not have_selector("#global-audio-player", text: track_a.name)
    end
  end
end
