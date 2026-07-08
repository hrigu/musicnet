# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Verwandte Tracks auf der Track-Detailseite (Intent 84, Stufe 1)", type: :system do
  fixtures :users

  before { login_as(users(:one), scope: :user) }

  it "zeigt verwandte Tracks und schränkt sie per Kategorie-Filter ein, ohne die Seite neu zu laden" do
    track = create_playable_track("RSpec RT System Origin", spotify_id: "rt-sys-1")
    match_in_category = create_playable_track("RSpec RT System In Category", spotify_id: "rt-sys-2")
    match_outside_category = create_playable_track("RSpec RT System Outside", spotify_id: "rt-sys-3")
    emotion = Category.create!(name: "RSpec Emotion RT System")
    quality = Category.create!(name: "RSpec Qualitaet RT System")
    emotion_tag = emotion.tags.create!(name: "RSpec Froehlich RT System", aliases: "x")
    quality_tag = quality.tags.create!(name: "RSpec Tanzbar RT System", aliases: "y")
    TrackTag.create!(track: track, tag: emotion_tag, strength: 5)
    TrackTag.create!(track: track, tag: quality_tag, strength: 5)
    TrackTag.create!(track: match_in_category, tag: emotion_tag, strength: 5)
    TrackTag.create!(track: match_outside_category, tag: quality_tag, strength: 5)

    visit track_path(track)

    within("##{ActionView::RecordIdentifier.dom_id(track, :related_tracks)}") do
      expect(page).to have_content("RSpec RT System In Category")
      expect(page).to have_content("RSpec RT System Outside")

      uncheck emotion.name
      check quality.name
      click_button "Filtern"

      expect(page).to have_content("RSpec RT System Outside")
      expect(page).to_not have_content("RSpec RT System In Category")
    end
  end

  it "bietet einen Vorhören-Button pro verwandtem Track" do
    track = create_playable_track("RSpec RT System Origin 2", spotify_id: "rt-sys-4")
    related = create_playable_track("RSpec RT System Related", spotify_id: "rt-sys-5")
    category = Category.create!(name: "RSpec Emotion RT System 2")
    tag = category.tags.create!(name: "RSpec Froehlich RT System 2", aliases: "x")
    TrackTag.create!(track: track, tag: tag, strength: 5)
    TrackTag.create!(track: related, tag: tag, strength: 5)

    visit track_path(track)

    within("##{ActionView::RecordIdentifier.dom_id(track, :related_tracks)}") do
      within("tr", text: "RSpec RT System Related") do
        expect(page).to have_button("🎧")
      end
    end
  end
end
