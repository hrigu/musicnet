# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Track-Zeilen-Buttons Layout (Intent 51 Nachtrag)", type: :system do
  fixtures :users

  before { login_as(users(:one), scope: :user) }

  it "alle Buttons in der Datei-Spalte (Vorhören, Play, Queue) sind sichtbar, nicht abgeschnitten" do
    track = create_playable_track("RSpec Layout Track", spotify_id: "layout-check")

    visit tracks_path

    table_right_edge = page.evaluate_script("document.querySelector('.table-tracks').getBoundingClientRect().right")
    button_right_edges = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("#audio_file_track_#{track.id} button"))
        .map((el) => el.getBoundingClientRect().right)
    JS

    expect(button_right_edges.size).to eq(3)
    expect(button_right_edges).to all(be <= table_right_edge)
  end

  it "der Tag-Entfernen-Button (×) überlappt die Datei-Spalte nicht (Intent 89)" do
    track = create_playable_track("RSpec Layout Tag Entfernen Track", spotify_id: "layout-tag-remove")
    category = Category.create!(name: "RSpec Layout Tag Entfernen Kategorie")
    tag = category.tags.create!(name: "RSpec Layout Tag Entfernen Sehr Langer Tag Name", aliases: "x")
    TrackTag.create!(track:, tag:, strength: 5)

    visit tracks_path

    file_column_left_edge = page.evaluate_script("document.querySelector('#audio_file_track_#{track.id}').getBoundingClientRect().left")
    remove_button_right_edge = page.evaluate_script(<<~JS)
      document.querySelector("form[action='/track_tags/#{TrackTag.last.id}'] button").getBoundingClientRect().right
    JS

    expect(remove_button_right_edge).to be <= file_column_left_edge
  end
end
