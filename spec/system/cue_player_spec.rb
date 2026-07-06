require "rails_helper"

RSpec.describe "Cue-/Vorhörkanal (Intent 51)", type: :system do
  fixtures :users

  before { login_as(users(:one), scope: :user) }

  it "unterbricht die laufende Queue-Wiedergabe im Haupt-Player nicht" do
    playing = create_track_with_real_audio("RSpec Playing Track", spotify_id: "cue-playing")
    candidate = create_track_with_real_audio("RSpec Cue Candidate", spotify_id: "cue-candidate")

    visit tracks_path
    play_button_for(playing.name).click
    sleep 0.3
    expect(page).to have_selector("#global-audio-player", text: playing.name)
    main_player_playing_before = page.evaluate_script("!document.querySelector('#global-audio-player audio').paused")

    cue_button_for(candidate.name).click
    sleep 0.3

    expect(page).to have_selector("#global-audio-player", text: candidate.name)
    main_player_still_shows_playing_track = page.evaluate_script(
      "document.querySelector('[data-audio-player-target=name]').textContent"
    )
    main_player_still_playing = page.evaluate_script("!document.querySelector('#global-audio-player audio').paused")

    expect(main_player_playing_before).to be(true)
    expect(main_player_still_shows_playing_track).to eq(playing.name)
    expect(main_player_still_playing).to be(true)
  end

  it "zeigt den Namen des vorgehörten Tracks im Cue-Kanal" do
    track = create_playable_track("RSpec Cue Name Track", spotify_id: "cue-name")

    visit tracks_path
    cue_button_for(track.name).click

    expect(page).to have_selector("[data-cue-player-target='name']", text: track.name)
  end

  it "wechselt den Cue-Kanal-Inhalt bei einem zweiten Vorhör-Klick" do
    first = create_playable_track("RSpec Cue First", spotify_id: "cue-first")
    second = create_playable_track("RSpec Cue Second", spotify_id: "cue-second")

    visit tracks_path
    cue_button_for(first.name).click
    expect(page).to have_selector("[data-cue-player-target='name']", text: first.name)

    cue_button_for(second.name).click

    expect(page).to have_selector("[data-cue-player-target='name']", text: second.name)
  end

  it "hat eigene, getrennte Ausgabegerät-Bedienelemente für Haupt- und Cue-Kanal (Nachtrag)" do
    visit tracks_path

    expect(page).to have_button("Ausgabegerät (Hauptkanal)")
    expect(page).to have_button("Ausgabegerät (Vorhören)")
  end

  it "zeigt ein Kanal-Symbol beim Hauptkanal, analog zum 🎧-Symbol des Cue-Kanals (Intent 67 Nachtrag)" do
    visit tracks_path

    expect(page).to have_selector("[title='Hauptkanal']", text: "🔊")
    expect(page).to have_selector("[title='Vorhörkanal']", text: "🎧")
  end

  it "zeigt Titel mit Hauptkuenstler und verlinkt auf die Track-Detailseite (Intent 67 Nachtrag)" do
    track = create_playable_track("RSpec Cue Title", spotify_id: "cue-title", artist_name: "RSpec Cue Hauptkuenstler")

    visit tracks_path
    cue_button_for(track.name).click

    name_link = page.find("[data-cue-player-target='name']")
    aggregate_failures do
      expect(name_link.text).to eq("RSpec Cue Title – RSpec Cue Hauptkuenstler")
      expect(name_link[:href]).to end_with(track_path(track))
    end
  end

  it "positioniert den Ausgabegeraet-Link rechts, wie beim Hauptkanal (Intent 67 Nachtrag)" do
    visit tracks_path

    main_right = page.evaluate_script(
      "document.querySelector('[data-audio-player-target=chooseButton]').getBoundingClientRect().right"
    )
    cue_right = page.evaluate_script(
      "document.querySelector('[data-cue-player-target=chooseButton]').getBoundingClientRect().right"
    )

    expect(cue_right).to be_within(2).of(main_right)
  end

  it "faerbt den Vorhoer-Button des gerade spielenden Tracks rot mit Pause-Symbol (Nachtrag)" do
    track = create_track_with_real_audio("RSpec Cue Live State Track", spotify_id: "cue-live-state")

    visit tracks_path
    cue_button_for(track.name).click
    sleep 0.3

    button = cue_button_for(track.name)
    expect(button.text.strip).to eq("⏸")
    expect(button[:class]).to include("btn-danger")
  end

  it "faerbt den vorherigen Button zurueck, wenn ein anderer Track vorgehoert wird (Nachtrag)" do
    first = create_track_with_real_audio("RSpec Cue Live First", spotify_id: "cue-live-first")
    second = create_track_with_real_audio("RSpec Cue Live Second", spotify_id: "cue-live-second")

    visit tracks_path
    cue_button_for(first.name).click
    sleep 0.3
    cue_button_for(second.name).click
    sleep 0.3

    expect(cue_button_for(first.name).text.strip).to eq("🎧")
    expect(cue_button_for(first.name)[:class]).to_not include("btn-danger")
    expect(cue_button_for(second.name).text.strip).to eq("⏸")
    expect(cue_button_for(second.name)[:class]).to include("btn-danger")
  end

  it "beendet das Vorhören per Klick auf den aktiven Button (Nachtrag)" do
    track = create_track_with_real_audio("RSpec Cue Live End Track", spotify_id: "cue-live-end")

    visit tracks_path
    cue_button_for(track.name).click
    sleep 0.3
    expect(cue_button_for(track.name).text.strip).to eq("⏸")

    cue_button_for(track.name).click
    sleep 0.3

    expect(cue_button_for(track.name).text.strip).to eq("🎧")
    expect(cue_button_for(track.name)[:class]).to_not include("btn-danger")
    cue_audio_paused = page.evaluate_script("document.querySelector('[data-cue-player-target=audio]').paused")
    expect(cue_audio_paused).to be(true)
  end

  it "zeigt den roten Live-Zustand auch nach einer Seitennavigation weg und zurueck (Nachtrag)" do
    track = create_track_with_real_audio("RSpec Cue Live Navigate Track", spotify_id: "cue-live-navigate")

    visit tracks_path
    cue_button_for(track.name).click
    sleep 0.3
    expect(cue_button_for(track.name).text.strip).to eq("⏸")

    click_link "Artists"
    click_link "Tracks"

    button = cue_button_for(track.name)
    expect(button.text.strip).to eq("⏸")
    expect(button[:class]).to include("btn-danger")
  end

  it "faerbt auch den Play/Pause-Button der unteren Leiste rot, waehrend vorgehoert wird (Nachtrag)" do
    track = create_track_with_real_audio("RSpec Cue Bar Red Track", spotify_id: "cue-bar-red")

    visit tracks_path
    cue_button_for(track.name).click
    sleep 0.3

    bar_button = page.find("[data-cue-player-target='toggleButton']")
    expect(bar_button[:class]).to include("btn-danger")

    bar_button.click
    sleep 0.3

    expect(bar_button[:class]).to_not include("btn-danger")
  end
end
