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

  it "wechselt zum neuen Track, wenn ein anderer Play-Button geklickt und bestaetigt wird" do
    track_a = create_track_with_real_audio("System Spec Gamma", spotify_id: "sys-gamma")
    track_b = create_track_with_real_audio("System Spec Delta", spotify_id: "sys-delta")

    visit tracks_path
    play_button_for(track_a.name).click
    sleep 0.3
    expect(page).to have_selector("#global-audio-player", text: track_a.name)

    accept_confirm { play_button_for(track_b.name).click }

    aggregate_failures do
      expect(page).to have_selector("#global-audio-player", text: track_b.name)
      expect(page).to_not have_selector("#global-audio-player", text: track_a.name)
    end
  end

  it "laesst den laufenden Track unveraendert, wenn der Wechsel abgebrochen wird (Intent 62)" do
    track_a = create_track_with_real_audio("RSpec Main Guard First", spotify_id: "main-guard-first")
    track_b = create_track_with_real_audio("RSpec Main Guard Second", spotify_id: "main-guard-second")

    visit tracks_path
    play_button_for(track_a.name).click
    sleep 0.3

    dismiss_confirm { play_button_for(track_b.name).click }
    sleep 0.3

    aggregate_failures do
      expect(page).to have_selector("#global-audio-player", text: track_a.name)
      still_playing = page.evaluate_script("!document.querySelector('#global-audio-player audio').paused")
      expect(still_playing).to be(true)
    end
  end

  it "pausiert erst nach Bestaetigung, wenn der aktive Button erneut geklickt wird (Intent 62)" do
    track = create_track_with_real_audio("RSpec Main Guard Toggle", spotify_id: "main-guard-toggle")

    visit tracks_path
    play_button_for(track.name).click
    sleep 0.3

    dismiss_confirm { play_button_for(track.name).click }
    sleep 0.3
    still_playing = page.evaluate_script("!document.querySelector('#global-audio-player audio').paused")
    expect(still_playing).to be(true)

    accept_confirm { play_button_for(track.name).click }
    sleep 0.3

    paused = page.evaluate_script("document.querySelector('#global-audio-player audio').paused")
    expect(paused).to be(true)
  end

  it "fragt nicht nach, wenn im Hauptkanal noch nichts spielt (Intent 62)" do
    track = create_playable_track("RSpec Main Guard No Dialog", spotify_id: "main-guard-no-dialog")

    visit tracks_path

    expect { play_button_for(track.name).click }.to_not raise_error
    expect(page).to have_selector("#global-audio-player", text: track.name)
  end

  it "faerbt den Play-Button des gerade spielenden Tracks gruen mit Pause-Symbol (Intent 62)" do
    track = create_track_with_real_audio("RSpec Main Live State Track", spotify_id: "main-live-state")

    visit tracks_path
    play_button_for(track.name).click
    sleep 0.3

    button = play_button_for(track.name)
    expect(button.text.strip).to eq("⏸")
    expect(button[:class]).to include("btn-success")
  end

  it "faerbt auch den Play/Pause-Button der unteren Leiste gruen, waehrend abgespielt wird (Intent 62)" do
    track = create_track_with_real_audio("RSpec Main Bar Green Track", spotify_id: "main-bar-green")

    visit tracks_path
    play_button_for(track.name).click
    sleep 0.3

    bar_button = page.find("[data-audio-player-target='toggleButton']")
    expect(bar_button[:class]).to include("btn-success")

    bar_button.click
    sleep 0.3

    expect(bar_button[:class]).to_not include("btn-success")
  end

  it "faerbt den vorherigen Button zurueck, wenn ein anderer Track gestartet wird (Intent 62)" do
    first = create_track_with_real_audio("RSpec Main Live First", spotify_id: "main-live-first")
    second = create_track_with_real_audio("RSpec Main Live Second", spotify_id: "main-live-second")

    visit tracks_path
    play_button_for(first.name).click
    sleep 0.3
    accept_confirm { play_button_for(second.name).click }
    sleep 0.3

    expect(play_button_for(first.name).text.strip).to eq("▶")
    expect(play_button_for(first.name)[:class]).to_not include("btn-success")
    expect(play_button_for(second.name).text.strip).to eq("⏸")
    expect(play_button_for(second.name)[:class]).to include("btn-success")
  end

  it "zeigt den gruenen Live-Zustand auch nach einer Seitennavigation weg und zurueck (Intent 62)" do
    track = create_track_with_real_audio("RSpec Main Live Navigate", spotify_id: "main-live-navigate")

    visit tracks_path
    play_button_for(track.name).click
    sleep 0.3
    expect(play_button_for(track.name).text.strip).to eq("⏸")

    click_link "Artists"
    click_link "Tracks"

    button = play_button_for(track.name)
    expect(button.text.strip).to eq("⏸")
    expect(button[:class]).to include("btn-success")
  end

  it "zeigt Titel mit Hauptkuenstler und verlinkt auf die Track-Detailseite (Intent 67)" do
    track = create_playable_track("RSpec Player Title", spotify_id: "player-title", artist_name: "RSpec Hauptkuenstler")

    visit tracks_path
    play_button_for(track.name).click

    name_link = page.find("[data-audio-player-target='name']")
    aggregate_failures do
      expect(name_link.text).to eq("RSpec Player Title – RSpec Hauptkuenstler")
      expect(name_link[:href]).to end_with(track_path(track))
    end
  end

  it "gibt der Titelanzeige mehr Platz als dem Fortschrittsbalken (Intent 67 Nachtrag)" do
    track = create_track_with_real_audio("RSpec Player Width", spotify_id: "player-width")

    visit tracks_path
    play_button_for(track.name).click
    sleep 0.3

    name_width = page.evaluate_script(
      "document.querySelector('[data-audio-player-target=name]').getBoundingClientRect().width"
    )
    progress_width = page.evaluate_script(
      "document.querySelector('[data-audio-player-target=progress]').getBoundingClientRect().width"
    )

    aggregate_failures do
      expect(name_width).to be > 400
      expect(progress_width).to be < 250
    end
  end

  it "zeigt ein zuvor gewaehltes Ausgabegeraet-Label sofort nach dem Laden an (Intent 68)" do
    visit tracks_path
    page.execute_script(<<~JS)
      localStorage.setItem('musicnet:mainPlayerSinkId', 'rspec-fake-device')
      localStorage.setItem('musicnet:mainPlayerSinkId:label', 'RSpec Externe Box')
    JS

    visit tracks_path

    expect(page).to have_selector("[data-audio-player-target='deviceName']", text: "RSpec Externe Box")
  end

  it "blendet Play-Button und Titel-Link erst nach dem ersten Abspielen ein und danach dauerhaft (Intent 69)" do
    track = create_playable_track("RSpec Empty State Main", spotify_id: "empty-state-main")

    visit tracks_path
    expect(page).to_not have_selector("[data-audio-player-target='toggleButton']")
    expect(page).to_not have_selector("[data-audio-player-target='name']")

    play_button_for(track.name).click
    sleep 0.3

    aggregate_failures do
      expect(page).to have_selector("[data-audio-player-target='toggleButton']")
      expect(page).to have_selector("[data-audio-player-target='name']", text: track.name)
    end
  end

  it "zeigt kein Ausgabegeraet-Label, wenn noch nie eines gewaehlt wurde (Intent 68)" do
    visit tracks_path

    expect(page.find("[data-audio-player-target='deviceName']").text).to eq("")
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
