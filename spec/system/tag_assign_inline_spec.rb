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
    track = create_playable_track("RSpec Inline Assign Track 2", spotify_id: "inline-assign-2")
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
end
