require "rails_helper"

RSpec.describe "Inline-Editieren der Tag-Stärke auf der Tracks-Indexseite (Intent 81)", type: :system do
  fixtures :users

  before { login_as(users(:one), scope: :user) }

  it "ändert die Stärke per Klick aufs Badge, Zahlenfeld und Enter" do
    track = create_playable_track("RSpec Inline Track", spotify_id: "inline-1")
    category = Category.create!(name: "RSpec Emotion Inline")
    tag = category.tags.create!(name: "RSpec Inline Tag", aliases: "x")
    track_tag = TrackTag.create!(track: track, tag: tag, strength: 3)

    visit tracks_path
    expect(page).to have_content("RSpec Inline Tag · 3")

    find("[data-tag-strength-target='badge']", text: "RSpec Inline Tag · 3").click
    field = find("[data-tag-strength-target='input']")
    field.fill_in(with: "9")
    field.send_keys(:enter)

    expect(page).to have_content("RSpec Inline Tag · 9")
    expect(page).to_not have_content("RSpec Inline Tag · 3")
    expect(track_tag.reload.strength).to eq(9)
  end

  it "bricht mit Escape ab, ohne zu speichern" do
    track = create_playable_track("RSpec Inline Track 2", spotify_id: "inline-2")
    category = Category.create!(name: "RSpec Emotion Inline Escape")
    tag = category.tags.create!(name: "RSpec Inline Escape", aliases: "x")
    track_tag = TrackTag.create!(track: track, tag: tag, strength: 4)

    visit tracks_path
    find("[data-tag-strength-target='badge']", text: "RSpec Inline Escape · 4").click
    field = find("[data-tag-strength-target='input']")
    field.fill_in(with: "10")
    field.send_keys(:escape)

    expect(page).to have_content("RSpec Inline Escape · 4")
    expect(track_tag.reload.strength).to eq(4)
  end

  it "bricht ab, wenn ausserhalb des Tags geklickt wird, ohne zu speichern" do
    track = create_playable_track("RSpec Inline Track 3", spotify_id: "inline-3")
    category = Category.create!(name: "RSpec Emotion Inline Outside")
    tag = category.tags.create!(name: "RSpec Inline Outside", aliases: "x")
    track_tag = TrackTag.create!(track: track, tag: tag, strength: 5)

    visit tracks_path
    find("[data-tag-strength-target='badge']", text: "RSpec Inline Outside · 5").click
    field = find("[data-tag-strength-target='input']")
    field.fill_in(with: "1")

    find("h1", text: "Meine Tracks").click

    expect(page).to have_content("RSpec Inline Outside · 5")
    expect(track_tag.reload.strength).to eq(5)
  end

  it "schliesst ein offenes Tag automatisch, wenn ein anderes Tag angeklickt wird" do
    track = create_playable_track("RSpec Inline Track 4", spotify_id: "inline-4")
    category = Category.create!(name: "RSpec Emotion Inline Zwei")
    tag_a = category.tags.create!(name: "RSpec Inline A", aliases: "a")
    tag_b = category.tags.create!(name: "RSpec Inline B", aliases: "b")
    TrackTag.create!(track: track, tag: tag_a, strength: 2)
    TrackTag.create!(track: track, tag: tag_b, strength: 6)

    visit tracks_path
    find("[data-tag-strength-target='badge']", text: "RSpec Inline A · 2").click
    expect(page).to have_css("[data-tag-strength-target='input']", count: 1)

    find("[data-tag-strength-target='badge']", text: "RSpec Inline B · 6").click

    expect(page).to have_css("[data-tag-strength-target='input']", count: 1)
    expect(page).to have_content("RSpec Inline A · 2")
  end

  it "laesst das Badge nach dem Speichern kurz aufglimmen" do
    track = create_playable_track("RSpec Inline Track 5", spotify_id: "inline-5")
    category = Category.create!(name: "RSpec Emotion Inline Glow")
    tag = category.tags.create!(name: "RSpec Inline Glow", aliases: "x")
    track_tag = TrackTag.create!(track: track, tag: tag, strength: 3)

    visit tracks_path
    find("[data-tag-strength-target='badge']", text: "RSpec Inline Glow · 3").click
    field = find("[data-tag-strength-target='input']")
    field.fill_in(with: "7")
    field.send_keys(:enter)

    expect(page).to have_content("RSpec Inline Glow · 7")
    expect(page).to have_css(".tag-just-saved")
  end
end
