# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Bestehendes Tag inline in der Tracks-Liste zuweisen (Intent 83)", type: :system do
  fixtures :users

  before { login_as(users(:one), scope: :user) }

  it "weist ein bestehendes Tag per Klick auf '+' und Auswahl aus der Suche zu" do
    track = create_playable_track("RSpec Inline Assign Track", spotify_id: "inline-assign-1")
    category = Category.create!(name: "RSpec Emotion Inline Assign")
    category.tags.create!(name: "RSpec Inline Assign Traurig", aliases: "sad")

    visit tracks_path
    within("tr", text: "RSpec Inline Assign Track") { find("[data-tag-assign-target='openButton']").click }
    fill_in "tag_search", with: "traurig"

    within("[data-tag-assign-target='results']") do
      expect(page).to have_button("RSpec Inline Assign Traurig")
      click_button("RSpec Inline Assign Traurig")
    end

    expect(page).to have_content("RSpec Inline Assign Traurig · 5")
    tag = Tag.find_by(name: "RSpec Inline Assign Traurig")
    expect(TrackTag.find_by(track: track, tag: tag).strength).to eq(5)
  end

  it "bietet keine Möglichkeit, hier ein neues Tag anzulegen" do
    create_playable_track("RSpec Inline Assign Track 2", spotify_id: "inline-assign-2")
    Category.create!(name: "RSpec Emotion Inline Assign Neu")

    visit tracks_path
    within("tr", text: "RSpec Inline Assign Track 2") { find("[data-tag-assign-target='openButton']").click }
    fill_in "tag_search", with: "Komplett Neuer Name"

    within("[data-tag-assign-target='results']") do
      expect(page).to have_content("Keine Treffer")
      expect(page).to_not have_button(text: /Neuer Tag/)
    end
  end

  it "blendet bereits zugewiesene Tags aus den Vorschlägen aus" do
    track = create_playable_track("RSpec Inline Assign Track 3", spotify_id: "inline-assign-3")
    category = Category.create!(name: "RSpec Emotion Inline Assign Schon")
    tag = category.tags.create!(name: "RSpec Inline Assign Schon Da", aliases: "x")
    TrackTag.create!(track: track, tag: tag, strength: 7)

    visit tracks_path
    within("tr", text: "RSpec Inline Assign Track 3") { find("[data-tag-assign-target='openButton']").click }
    fill_in "tag_search", with: "Schon Da"

    within("[data-tag-assign-target='results']") do
      expect(page).to have_content("Keine Treffer")
    end
  end

  it "bricht per Escape ab, ohne eine Zuordnung anzulegen" do
    track = create_playable_track("RSpec Inline Assign Track 4", spotify_id: "inline-assign-4")
    category = Category.create!(name: "RSpec Emotion Inline Assign Escape")
    category.tags.create!(name: "RSpec Inline Assign Escape Tag", aliases: "x")

    visit tracks_path
    within("tr", text: "RSpec Inline Assign Track 4") { find("[data-tag-assign-target='openButton']").click }
    field = find_field("tag_search")
    field.fill_in(with: "Escape")
    field.send_keys(:escape)

    expect(page).to have_selector("[data-tag-assign-target='openButton']", visible: true)
    expect(TrackTag.where(track: track).count).to eq(0)
  end

  it "zeigt zuletzt verwendete Tags als Vorschlaege und weist sie direkt zu" do
    seed_track = create_playable_track("RSpec Inline Suggestion Seed", spotify_id: "inline-suggestion-seed")
    target_track = create_playable_track("RSpec Inline Suggestion Target", spotify_id: "inline-suggestion-target")
    category = Category.create!(name: "RSpec Emotion Inline Vorschlag")
    tag = category.tags.create!(name: "RSpec Inline Vorschlag", aliases: "x")
    TrackTag.create!(track: seed_track, tag:, strength: 5)
    TagAssignment.create!(user: users(:one), tag:)

    visit tracks_path
    within("tr", text: "RSpec Inline Suggestion Target") do
      find("[data-tag-assign-target='openButton']").click
      expect(page).to have_button("RSpec Inline Vorschlag")
      click_button("RSpec Inline Vorschlag")
    end

    expect(page).to have_content("RSpec Inline Vorschlag · 5")
    expect(TrackTag.find_by(track: target_track, tag: tag)&.strength).to eq(5)
  end

  it "entfernt ein zugewiesenes Tag direkt von /tracks aus, ohne die Seite zu verlassen (Intent 89)" do
    track = create_playable_track("RSpec Inline Entfernen Track", spotify_id: "inline-remove-1")
    category = Category.create!(name: "RSpec Emotion Inline Entfernen")
    tag = category.tags.create!(name: "RSpec Inline Entfernen Tag", aliases: "x")
    TrackTag.create!(track: track, tag: tag, strength: 5)

    visit tracks_path
    expect(page).to have_content("RSpec Inline Entfernen Tag · 5")

    accept_confirm { within("tr", text: "RSpec Inline Entfernen Track") { click_button "×" } }

    aggregate_failures do
      expect(page).to have_current_path(tracks_path)
      expect(page).to_not have_content("RSpec Inline Entfernen Tag · 5")
      expect(TrackTag.where(track: track, tag: tag)).to be_empty
    end
  end

  it "entfernt ein zugewiesenes Tag von der Playlist-Ansicht aus, ohne die Seite zu verlassen (Intent 89)" do
    track = create_playable_track("RSpec Playlist Entfernen Track", spotify_id: "playlist-remove-1")
    playlist = Playlist.create!(name: "RSpec Playlist Entfernen", spotify_id: "pl-remove-1")
    PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
    category = Category.create!(name: "RSpec Emotion Playlist Entfernen")
    tag = category.tags.create!(name: "RSpec Playlist Entfernen Tag", aliases: "x")
    TrackTag.create!(track: track, tag: tag, strength: 5)

    visit playlist_path(playlist)
    expect(page).to have_content("RSpec Playlist Entfernen Tag · 5")

    accept_confirm { within("tr", text: "RSpec Playlist Entfernen Track") { click_button "×" } }

    aggregate_failures do
      expect(page).to have_current_path(playlist_path(playlist))
      expect(page).to_not have_content("RSpec Playlist Entfernen Tag · 5")
      expect(TrackTag.where(track: track, tag: tag)).to be_empty
    end
  end

  it "entfernt ein zugewiesenes Tag von der Artist-Ansicht aus, ohne die Seite zu verlassen (Intent 89)" do
    artist = Artist.create!(name: "RSpec Artist Entfernen", spotify_id: "artist-remove-1")
    track = create_playable_track("RSpec Artist Entfernen Track", spotify_id: "artist-remove-1", artist_name: nil)
    track.artists << artist
    category = Category.create!(name: "RSpec Emotion Artist Entfernen")
    tag = category.tags.create!(name: "RSpec Artist Entfernen Tag", aliases: "x")
    TrackTag.create!(track: track, tag: tag, strength: 5)

    visit artist_path(artist)
    expect(page).to have_content("RSpec Artist Entfernen Tag · 5")

    accept_confirm { within(first("tr", text: "RSpec Artist Entfernen Track")) { click_button "×" } }

    aggregate_failures do
      expect(page).to have_current_path(artist_path(artist))
      expect(page).to_not have_content("RSpec Artist Entfernen Tag · 5")
      expect(TrackTag.where(track: track, tag: tag)).to be_empty
    end
  end
end
