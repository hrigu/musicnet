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
end
