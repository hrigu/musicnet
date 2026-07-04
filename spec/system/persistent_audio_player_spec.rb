# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dauerhafte Track-Wiedergabe (Intent 40)", type: :system do
  fixtures :users

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

  it "springt an die per Slider gewaehlte Position im Track (Seek)" do
    track = create_track_with_real_audio("System Spec Seek", spotify_id: "sys-seek")

    visit tracks_path
    play_button_for(track.name).click
    sleep 1 # Metadaten (Dauer) muessen geladen sein, bevor der Slider einen sinnvollen max-Wert hat

    page.execute_script(<<~JS)
      const range = document.querySelector('#global-audio-player [data-audio-player-target=progress]')
      range.value = 3
      range.dispatchEvent(new Event('input', { bubbles: true }))
    JS
    sleep 0.5

    current_time = page.evaluate_script("document.querySelector('#global-audio-player audio').currentTime")
    expect(current_time).to be >= 2.9
  end
end
