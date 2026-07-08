# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Manuelles Tag-Zuweisen auf der Track-Detailseite (Intent 79)", type: :system do
  fixtures :users

  before { login_as(users(:one), scope: :user) }

  it "verknüpft einen bestehenden Tag über die Livesuche mit einer gewählten Stärke" do
    track = create_playable_track("RSpec Assign Track", spotify_id: "assign-1")
    category = Category.create!(name: "RSpec Emotion Assign")
    category.tags.create!(name: "RSpec Traurig Assign", aliases: "sad")

    visit track_path(track)
    click_button "+ Tag hinzufügen"
    fill_in "tag_search", with: "traurig"

    within("[data-tag-assign-target='results']") do
      expect(page).to have_button("RSpec Traurig Assign")
      click_button("RSpec Traurig Assign")
    end

    fill_in "strength", with: "8"
    click_button "Hinzufügen"

    expect(page).to have_content("RSpec Traurig Assign · 8")
  end

  it "legt einen neuen Tag mit gewählter Kategorie an und verknüpft ihn" do
    track = create_playable_track("RSpec Assign Track 2", spotify_id: "assign-2")
    category = Category.create!(name: "RSpec Emotion Neu Assign")

    visit track_path(track)
    click_button "+ Tag hinzufügen"
    fill_in "tag_search", with: "Brandneu"

    within("[data-tag-assign-target='results']") { click_button("Neuer Tag: „Brandneu“") }
    find("[data-tag-assign-target='categorySelect']").select(category.name)
    click_button "Weiter"
    fill_in "strength", with: "3"
    click_button "Hinzufügen"

    expect(page).to have_content("Brandneu · 3")
    tag = Tag.find_by(name: "Brandneu")
    expect(tag.category).to eq(category)
  end

  it "erlaubt den Abbruch beim Stärke-Schritt, um ein anderes Tag zu wählen" do
    track = create_playable_track("RSpec Assign Track 3", spotify_id: "assign-3")
    category = Category.create!(name: "RSpec Emotion Zurueck")
    falsches_tag = category.tags.create!(name: "RSpec Falsches Tag", aliases: "falsch")
    richtiges_tag = category.tags.create!(name: "RSpec Richtiges Tag", aliases: "richtig")

    visit track_path(track)
    click_button "+ Tag hinzufügen"
    fill_in "tag_search", with: "falsch"
    within("[data-tag-assign-target='results']") { click_button("RSpec Falsches Tag") }

    click_button "Zurück, anderes Tag wählen"

    expect(page).to have_field("tag_search", with: "")
    fill_in "tag_search", with: "richtig"
    within("[data-tag-assign-target='results']") { click_button("RSpec Richtiges Tag") }
    fill_in "strength", with: "6"
    click_button "Hinzufügen"

    expect(page).to have_content("RSpec Richtiges Tag · 6")
    expect(TrackTag.find_by(track: track, tag: falsches_tag)).to be_nil
    expect(TrackTag.find_by(track: track, tag: richtiges_tag).strength).to eq(6)
  end

  it "erlaubt den Abbruch beim Kategorie-Schritt eines neuen Tags" do
    track = create_playable_track("RSpec Assign Track 4", spotify_id: "assign-4")
    category = Category.create!(name: "RSpec Emotion Zurueck 2")
    category.tags.create!(name: "RSpec Doch Bestehend", aliases: "doch")

    visit track_path(track)
    click_button "+ Tag hinzufügen"
    fill_in "tag_search", with: "Falscherneuertag"
    within("[data-tag-assign-target='results']") { click_button("Neuer Tag: „Falscherneuertag“") }

    click_button "Zurück"

    expect(page).to have_field("tag_search", with: "")
    fill_in "tag_search", with: "doch"
    within("[data-tag-assign-target='results']") { click_button("RSpec Doch Bestehend") }
    fill_in "strength", with: "2"
    click_button "Hinzufügen"

    expect(page).to have_content("RSpec Doch Bestehend · 2")
    expect(Tag.find_by(name: "Falscherneuertag")).to be_nil
  end

  it "verknüpft einen bestehenden Tag rein per Tastatur (Pfeiltasten/Enter statt Klick)" do
    track = create_playable_track("RSpec Assign Track 5", spotify_id: "assign-5")
    category = Category.create!(name: "RSpec Emotion Tastatur")
    category.tags.create!(name: "RSpec Traurig Tastatur", aliases: "sad")

    visit track_path(track)
    click_button "+ Tag hinzufügen"
    search_field = find_field("tag_search")
    search_field.fill_in(with: "traurig")
    expect(page).to have_button("RSpec Traurig Tastatur")
    search_field.send_keys(:enter)

    strength_field = find_field("strength")
    strength_field.fill_in(with: "9")
    strength_field.send_keys(:enter)

    expect(page).to have_content("RSpec Traurig Tastatur · 9")
  end

  it "wählt mit Pfeil-runter den zweiten statt den ersten Treffer aus" do
    track = create_playable_track("RSpec Assign Track 6", spotify_id: "assign-6")
    category = Category.create!(name: "RSpec Emotion Pfeil")
    category.tags.create!(name: "RSpec Alpha Pfeil", aliases: "alpha")
    category.tags.create!(name: "RSpec Beta Pfeil", aliases: "beta")

    visit track_path(track)
    click_button "+ Tag hinzufügen"
    search_field = find_field("tag_search")
    search_field.fill_in(with: "pfeil")
    expect(page).to have_button("RSpec Beta Pfeil")

    search_field.send_keys(:down, :enter)
    strength_field = find_field("strength")
    strength_field.fill_in(with: "5")
    strength_field.send_keys(:enter)

    expect(page).to have_content("RSpec Beta Pfeil · 5")
    expect(Tag.find_by(name: "RSpec Alpha Pfeil").track_tags).to be_empty
  end

  it "legt einen neuen Tag rein per Tastatur an (kein Treffer -> Enter wählt \"Neuer Tag\")" do
    track = create_playable_track("RSpec Assign Track 7", spotify_id: "assign-7")
    category = Category.create!(name: "RSpec Emotion Tastatur Neu")

    visit track_path(track)
    click_button "+ Tag hinzufügen"
    search_field = find_field("tag_search")
    search_field.fill_in(with: "Tastaturtag")
    expect(page).to have_button("Neuer Tag: „Tastaturtag“")
    search_field.send_keys(:enter)

    category_select = find("[data-tag-assign-target='categorySelect']")
    category_select.send_keys(:enter)

    strength_field = find_field("strength")
    strength_field.fill_in(with: "4")
    strength_field.send_keys(:enter)

    expect(page).to have_content("Tastaturtag · 4")
    expect(Tag.find_by(name: "Tastaturtag").category).to eq(category)
  end

  it "entfernt einen zugewiesenen Tag nach Bestätigung" do
    track = create_playable_track("RSpec Assign Track 8", spotify_id: "assign-8")
    category = Category.create!(name: "RSpec Emotion Entfernen")
    tag = category.tags.create!(name: "RSpec Entfernbar", aliases: "x")
    TrackTag.create!(track: track, tag: tag, strength: 5)

    visit track_path(track)
    expect(page).to have_content("RSpec Entfernbar · 5")

    accept_confirm { find("button", text: "×").click }

    expect(page).to_not have_content("RSpec Entfernbar · 5")
    expect(TrackTag.find_by(track: track, tag: tag)).to be_nil
  end
end
