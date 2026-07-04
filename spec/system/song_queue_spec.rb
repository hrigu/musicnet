# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Song-Queue (Intent 41)", type: :system do
  fixtures :users

  before { login_as(users(:one), scope: :user) }

  it "fuegt einen Track der Queue hinzu" do
    track = create_playable_track("Queue Track Alpha", spotify_id: "queue-alpha")

    visit tracks_path
    enqueue_button_for(track.name).click

    expect(page).to have_selector("#audio-player-queue", text: track.name)
  end

  it "startet den ersten Track der Queue per Player-Play-Button, ohne dass zuvor je etwas gespielt wurde" do
    first = create_playable_track("Queue Direktstart Erster", spotify_id: "queue-direktstart-1")
    second = create_playable_track("Queue Direktstart Zweiter", spotify_id: "queue-direktstart-2")

    visit tracks_path
    enqueue_button_for(first.name).click
    enqueue_button_for(second.name).click

    player_toggle_button.click

    aggregate_failures do
      expect(page).to have_selector("#global-audio-player", text: first.name)
      expect(page).to_not have_selector("#audio-player-queue", text: first.name)
      expect(page).to have_selector("#audio-player-queue", text: second.name)
    end
  end

  it "ignoriert weitere Klicks, wenn die Queue bereits voll ist (max. 5)" do
    tracks = (1..6).map { |n| create_playable_track("Queue Voll #{n}", spotify_id: "queue-voll-#{n}") }

    visit tracks_path
    tracks.each { |track| enqueue_button_for(track.name).click }

    within("#audio-player-queue") do
      expect(page).to have_selector(".queue-entry", count: 5)
      expect(page).to have_content("Queue Voll 1")
      expect(page).to_not have_content("Queue Voll 6")
    end
  end

  it "entfernt einen Track manuell wieder aus der Queue" do
    track = create_playable_track("Queue Track Entfernen", spotify_id: "queue-entfernen")

    visit tracks_path
    enqueue_button_for(track.name).click
    expect(page).to have_selector("#audio-player-queue", text: track.name)

    within("#audio-player-queue") { click_button "×" }

    expect(page).to_not have_selector("#audio-player-queue", text: track.name)
  end

  it "zeigt den zuerst hinzugefuegten (naechsten) Track zuunterst, neue zuoberst" do
    first = create_playable_track("Queue Reihenfolge Erster", spotify_id: "queue-reihenfolge-1")
    second = create_playable_track("Queue Reihenfolge Zweiter", spotify_id: "queue-reihenfolge-2")

    visit tracks_path
    enqueue_button_for(first.name).click
    enqueue_button_for(second.name).click

    names = page.all("#audio-player-queue .queue-entry").map(&:text)
    expect(names).to eq(["#{second.name}\n×", "#{first.name}\n×"])
  end

  it "entfernt den richtigen Track, wenn mehrere in der Queue stehen" do
    first = create_playable_track("Queue Entfernen Erster", spotify_id: "queue-entfernen-1")
    second = create_playable_track("Queue Entfernen Zweiter", spotify_id: "queue-entfernen-2")

    visit tracks_path
    enqueue_button_for(first.name).click
    enqueue_button_for(second.name).click

    within("#audio-player-queue") { page.find(".queue-entry", text: first.name).click_button "×" }

    aggregate_failures do
      expect(page).to_not have_selector("#audio-player-queue", text: first.name)
      expect(page).to have_selector("#audio-player-queue", text: second.name)
    end
  end

  it "spielt automatisch den naechsten Track aus der Queue, wenn der aktuelle endet" do
    track_a = create_playable_track("Queue Aktuell", spotify_id: "queue-aktuell")
    track_b = create_playable_track("Queue Naechster", spotify_id: "queue-naechster")

    visit tracks_path
    play_button_for(track_a.name).click
    expect(page).to have_selector("#global-audio-player", text: track_a.name)
    enqueue_button_for(track_b.name).click
    expect(page).to have_selector("#audio-player-queue", text: track_b.name)

    page.execute_script("document.querySelector('#global-audio-player audio').dispatchEvent(new Event('ended'))")

    aggregate_failures do
      expect(page).to have_selector("#global-audio-player", text: track_b.name)
      expect(page).to_not have_selector("#audio-player-queue", text: track_b.name)
    end
  end

  it "ueberlebt einen Seitenwechsel dank data-turbo-permanent" do
    track = create_playable_track("Queue Ueberlebt", spotify_id: "queue-ueberlebt")

    visit tracks_path
    enqueue_button_for(track.name).click
    expect(page).to have_selector("#audio-player-queue", text: track.name)

    click_link "Playlists"

    expect(page).to have_content("Meine Playlists")
    expect(page).to have_selector("#audio-player-queue", text: track.name)
  end

  it "ueberlebt eine Navigation ueber einen data-turbo-frame=_top-Link aus dem Tracks-Frame heraus" do
    artist = Artist.create!(name: "Queue Bug Artist", spotify_id: "queue-bug-artist")
    first = create_playable_track("Queue TopLink Erster", spotify_id: "queue-toplink-1")
    first.update!(artists: [artist])
    second = create_playable_track("Queue TopLink Zweiter", spotify_id: "queue-toplink-2")

    visit tracks_path
    enqueue_button_for(first.name).click
    enqueue_button_for(second.name).click

    # Der Artist-Link in der Tracks-Tabelle nutzt data-turbo-frame: "_top", um aus
    # turbo_frame_tag "tracks" auszubrechen - anders als ein gewoehnlicher Top-Level-Link.
    first(:link, artist.name).click
    expect(page).to have_current_path(artist_path(artist))

    # Erneutes Enqueuen (hier: derselbe Track, der auf der Artist-Seite gelistet ist) erzwingt
    # ein renderQueue() und deckt damit auf, ob der interne Zustand zwischenzeitlich verloren ging.
    page.all("tr", text: first.name).first.find_button("Zur Queue hinzufügen").click

    aggregate_failures do
      expect(page).to have_selector("#audio-player-queue", text: second.name)
      expect(page).to have_selector("#audio-player-queue .queue-entry", count: 3)
    end
  end

  it "ueberlebt eine Suche auf /tracks (Turbo-Frame-Update)" do
    track = create_playable_track("Queue Suche", spotify_id: "queue-suche")

    visit tracks_path
    enqueue_button_for(track.name).click
    expect(page).to have_selector("#audio-player-queue", text: track.name)

    fill_in "q", with: track.name
    click_button "Suchen"

    expect(page).to have_selector("table", text: track.name)
    expect(page).to have_selector("#audio-player-queue", text: track.name)
  end
end
