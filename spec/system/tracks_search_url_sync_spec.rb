require "rails_helper"

RSpec.describe "Tracks-Suche in der URL gespiegelt (Intent 50)", type: :system do
  fixtures :users

  before { login_as(users(:one), scope: :user) }

  it "spiegelt eine Suche in der Browser-URL" do
    create_playable_track("RSpec Jazz Track", spotify_id: "url-jazz")
    Track.find_by(spotify_id: "url-jazz").update!(genre: "RSpec Jazz")

    visit tracks_path
    fill_in "q", with: "genre:jazz"
    click_button "Suchen"

    expect(page.current_url).to include("q=genre")
  end

  it "spiegelt Sortierung und Seitenwechsel in der Browser-URL" do
    (1..60).each { |n| create_playable_track("RSpec Sort Filler #{n}", spotify_id: "url-sort-#{n}") }

    visit tracks_path
    click_link "Dauer"
    expect(page.current_url).to include("sort=duration_ms")

    click_link "2"
    expect(page.current_url).to include("page=2")
  end

  it "stellt per Browser-Zurueck den vorherigen Zustand wieder her" do
    create_playable_track("RSpec Back Track", spotify_id: "url-back")

    visit tracks_path
    fill_in "q", with: "RSpec Back"
    click_button "Suchen"
    expect(page.current_url).to include("q=RSpec")

    page.go_back

    expect(page.current_url).to_not include("q=RSpec")
  end

  it "unterbricht die laufende Wiedergabe des persistenten Audio-Players nicht" do
    track = create_track_with_real_audio("RSpec Uninterrupted Track", spotify_id: "url-player")

    visit tracks_path
    play_button_for(track.name).click
    sleep 0.3
    page.execute_script("document.getElementById('global-audio-player').dataset.marker = 'still-here'")

    fill_in "q", with: "RSpec Uninterrupted"
    click_button "Suchen"

    marker = page.evaluate_script("document.getElementById('global-audio-player').dataset.marker")
    playing = page.evaluate_script("!document.querySelector('#global-audio-player audio').paused")
    expect(marker).to eq("still-here")
    expect(playing).to be(true)
  end
end
