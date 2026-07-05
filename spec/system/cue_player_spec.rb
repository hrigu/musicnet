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
end
