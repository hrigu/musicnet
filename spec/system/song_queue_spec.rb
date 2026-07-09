# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Song-Queue (Intent 41/42)", type: :system do
  fixtures :users

  before { login_as(users(:one), scope: :user) }

  it "zeigt weder Platzhaltertext noch das Sichern-Formular, solange die Queue leer ist" do
    create_playable_track("Queue Leer Check", spotify_id: "queue-leer-check")

    visit tracks_path

    within("#audio-player-queue") do
      expect(page).to_not have_content("Queue leer")
      expect(page).to_not have_button("Als Playlist sichern")
    end
  end

  it "blendet das Sichern-Formular wieder aus, sobald die Queue durch Entfernen wieder leer wird" do
    track = create_playable_track("Queue Leer Nach Entfernen", spotify_id: "queue-leer-entfernen")

    visit tracks_path
    enqueue_button_for(track.name).click
    expect(page).to have_button("Als Playlist sichern")

    within("#audio-player-queue") { click_button "×" }

    expect(page).to_not have_button("Als Playlist sichern")
  end

  it "verdeckt die Pagination nicht, wenn die Queue voll ist" do
    (1..50).each { |n| create_playable_track("Overlap Filler #{n}", spotify_id: "overlap-filler-#{n}") }
    to_queue = %w[A B C D E].map do |letter|
      create_playable_track("AAA Overlap Queue #{letter}", spotify_id: "overlap-queue-#{letter}")
    end

    visit tracks_path
    to_queue.each { |t| enqueue_button_for(t.name).click }
    expect(page).to have_selector("#audio-player-queue .queue-entry", count: 5)

    page.scroll_to(page.find(".pagy-bootstrap"))
    pagination_bottom = page.evaluate_script(
      "document.querySelector('.pagy-bootstrap').getBoundingClientRect().bottom"
    )
    player_top = page.evaluate_script("document.getElementById('global-audio-player').getBoundingClientRect().top")

    expect(pagination_bottom).to be <= player_top
  end

  it "fuegt einen Track der Queue hinzu" do
    track = create_playable_track("Queue Track Alpha", spotify_id: "queue-alpha")

    visit tracks_path
    enqueue_button_for(track.name).click

    expect(page).to have_selector("#audio-player-queue", text: track.name)
  end

  it "zeigt Kuenstler und Playlist zusaetzlich zum Titel in der Queue an" do
    attrs = { spotify_id: "queue-details", artist_name: "Queue Details Artist", playlist_name: "Fusion Details" }
    track = create_playable_track("Queue Track Details", **attrs)
    playlist = Playlist.find_by(name: "Fusion Details")

    visit tracks_path
    enqueue_button_for(track.name).click

    within("#audio-player-queue") do
      expect(page).to have_content(track.name)
      expect(page).to have_content("Queue Details Artist")
      expect(page).to have_content(ApplicationController.helpers.playlist_short_name(playlist))
    end
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

  it "verlinkt den Titel im Player auf die Detailseite, auch wenn der Track ueber die Queue " \
     "nachgerueckt ist (Bugfix: trackId kam als snake_case track_id vom Server)" do
    track_a = create_playable_track("Queue Link Aktuell", spotify_id: "queue-link-aktuell")
    track_b = create_playable_track("Queue Link Naechster", spotify_id: "queue-link-naechster")

    visit tracks_path
    play_button_for(track_a.name).click
    expect(page).to have_selector("#global-audio-player", text: track_a.name)
    enqueue_button_for(track_b.name).click
    expect(page).to have_selector("#audio-player-queue", text: track_b.name)

    page.execute_script("document.querySelector('#global-audio-player audio').dispatchEvent(new Event('ended'))")
    expect(page).to have_selector("[data-audio-player-target='name']", text: track_b.name)

    name_link = page.find("[data-audio-player-target='name']")
    expect(name_link[:href]).to end_with(track_path(track_b))
  end

  it "erfasst einen ueber die Queue nachgerueckten Track in der lokalen Playback-Historie" do
    # Echte (stumme) Audiodatei noetig, nicht nur eine leere: persistPlayback() haengt am
    # play()-Promise - bei einer leeren Datei rejected der Browser das Promise (kein dekodierbarer
    # Inhalt), .catch(() => {}) schluckt das dann still, ohne persistPlayback je aufzurufen.
    track_a = create_track_with_real_audio("Queue Historie Aktuell", spotify_id: "queue-historie-aktuell")
    track_b = create_track_with_real_audio("Queue Historie Naechster", spotify_id: "queue-historie-naechster")

    visit tracks_path
    play_button_for(track_a.name).click
    expect(page).to have_selector("#global-audio-player", text: track_a.name)
    enqueue_button_for(track_b.name).click
    expect(page).to have_selector("#audio-player-queue", text: track_b.name)

    page.execute_script("document.querySelector('#global-audio-player audio').dispatchEvent(new Event('ended'))")
    expect(page).to have_selector("[data-audio-player-target='name']", text: track_b.name)

    # persistPlayback() feuert einen eigenen, unabhaengigen fetch nach dem play()-Promise - erst
    # nachdem navigator.geolocation.getCurrentPosition() beantwortet ist (Timeout dort: 2s, siehe
    # audio_player_controller.js), Capybara wartet nur auf DOM-Aenderungen, nicht auf diesen
    # zusaetzlichen Request.
    sleep 2.5
    expect(DjSessionPlayback.where(track: track_b)).to exist
  end

  it "ueberlebt einen Seitenwechsel (server-gerendert, kein Client-Zustand mehr noetig)" do
    track = create_playable_track("Queue Ueberlebt", spotify_id: "queue-ueberlebt")

    visit tracks_path
    enqueue_button_for(track.name).click
    expect(page).to have_selector("#audio-player-queue", text: track.name)

    click_link "Playlists"

    expect(page).to have_content("Meine Playlists")
    expect(page).to have_selector("#audio-player-queue", text: track.name)
  end

  it "ueberlebt einen echten Reload (F5) - die urspruengliche Motivation fuer Intent 42" do
    track = create_playable_track("Queue Reload", spotify_id: "queue-reload")

    visit tracks_path
    enqueue_button_for(track.name).click
    expect(page).to have_selector("#audio-player-queue", text: track.name)

    # Capybara/Cuprite fuehrt visit als echte Browser-Navigation aus (kein Turbo-Drive-Visit
    # innerhalb der laufenden Seite) - im Gegensatz zu click_link/click_button oben entspricht das
    # also einem echten Reload, nicht nur einer Turbo-Navigation.
    visit tracks_path

    expect(page).to have_selector("#audio-player-queue", text: track.name)
  end

  it "ueberlebt eine Navigation ueber einen data-turbo-frame=_top-Link aus dem Tracks-Frame heraus" do
    # Historischer Regressionstest (Intent 41 Nachtrag 3.5): mit der frueheren, rein clientseitigen
    # Queue verlor genau dieser Navigationspfad den Queue-Zustand, weil Turbo den Stimulus-
    # Controller dabei neu verbindet. Seit Intent 42 ist die Queue Server-Zustand, daher kann das
    # strukturell nicht mehr passieren - der Test bleibt als Regressionsschutz bestehen.
    artist = Artist.create!(name: "Queue Bug Artist", spotify_id: "queue-bug-artist")
    first = create_playable_track("Queue TopLink Erster", spotify_id: "queue-toplink-1")
    first.update!(artists: [artist])
    second = create_playable_track("Queue TopLink Zweiter", spotify_id: "queue-toplink-2")

    visit tracks_path
    enqueue_button_for(first.name).click
    enqueue_button_for(second.name).click

    first(:link, artist.name).click
    expect(page).to have_current_path(artist_path(artist))

    aggregate_failures do
      expect(page).to have_selector("#audio-player-queue", text: first.name)
      expect(page).to have_selector("#audio-player-queue", text: second.name)
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

  it "markiert einen Track sofort als 'in Queue', ohne dass ein Reload noetig ist" do
    track = create_playable_track("Queue Markiert", spotify_id: "queue-markiert")

    visit tracks_path
    enqueue_button_for(track.name).click

    expect(page).to have_selector("tr", text: "in Queue")
  end

  it "versteckt Play-/Queue-Button eines gequeueten Tracks und zeigt sie nach Entfernen wieder" do
    track = create_playable_track("Queue Buttons Versteckt", spotify_id: "queue-buttons-versteckt")

    visit tracks_path
    row = page.find("tr", text: track.name)
    expect(row).to have_button("Abspielen")
    expect(row).to have_button("Zur Queue hinzufügen")

    enqueue_button_for(track.name).click

    row = page.find("tr", text: track.name)
    aggregate_failures do
      expect(row).to have_content("in Queue")
      expect(row).to_not have_button("Abspielen")
      expect(row).to_not have_button("Zur Queue hinzufügen")
    end

    within("#audio-player-queue") { click_button "×" }

    row = page.find("tr", text: track.name)
    aggregate_failures do
      expect(row).to_not have_content("in Queue")
      expect(row).to have_button("Abspielen")
      expect(row).to have_button("Zur Queue hinzufügen")
    end
  end

  it "entfernt die 'in Queue'-Markierung sofort wieder, wenn der Track aus der Queue genommen wird" do
    track = create_playable_track("Queue Entmarkiert", spotify_id: "queue-entmarkiert")

    visit tracks_path
    enqueue_button_for(track.name).click
    expect(page).to have_selector("tr", text: "in Queue")

    within("#audio-player-queue") { click_button "×" }

    expect(page).to_not have_selector("tr", text: "in Queue")
  end

  it "entfernt die Markierung auch, wenn der Track ueber den Player-Play-Button aus der Queue genommen wird" do
    track = create_playable_track("Queue Advance Markiert", spotify_id: "queue-advance-markiert")

    visit tracks_path
    enqueue_button_for(track.name).click
    expect(page).to have_selector("tr", text: "in Queue")

    player_toggle_button.click

    expect(page).to_not have_selector("tr", text: "in Queue")
  end

  it "legt beim Sichern eine lokale Playlist mit den gequeueten Tracks an, ohne die Queue zu leeren" do
    first = create_playable_track("Queue Save Erster", spotify_id: "queue-save-1")
    second = create_playable_track("Queue Save Zweiter", spotify_id: "queue-save-2")

    visit tracks_path
    enqueue_button_for(first.name).click
    enqueue_button_for(second.name).click

    fill_in "Playlist-Name", with: "Aus der Queue gesichert"
    click_button "Als Playlist sichern"

    expect(page).to have_content("Aus der Queue gesichert")
    playlist = Playlist.find_by(name: "Aus der Queue gesichert")
    expect(playlist.tracks).to contain_exactly(first, second)
    expect(playlist.spotify_id).to be_nil

    visit tracks_path
    expect(page).to have_selector("#audio-player-queue", text: first.name)
  end
end
