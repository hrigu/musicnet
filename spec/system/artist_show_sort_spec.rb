# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Artist-Detailseite - Tracks in der Seite sortieren (Intent 63)", type: :system do
  fixtures :users

  before { login_as(users(:one), scope: :user) }

  it "bleibt beim Sortieren auf der Artist-Seite und sortiert die Tabelle in der Seite" do
    album = Album.create!(name: "Album", spotify_id: "alb-sys-63")
    artist = Artist.create!(name: "RSpec Sort Artist", spotify_id: "art-sys-63")
    Track.create!(name: "B Track", spotify_id: "trk-sys-63-b", album: album, artists: [artist],
                  duration_ms: 200_000)
    Track.create!(name: "A Track", spotify_id: "trk-sys-63-a", album: album, artists: [artist],
                  duration_ms: 100_000)

    visit artist_path(artist)
    click_link "Dauer"

    aggregate_failures do
      expect(page.current_url).to include("/artists/#{artist.id}")
      expect(page.current_url).to_not include("/tracks")
      names = page.all("tbody tr th a").map(&:text)
      expect(names).to eq(["A Track", "B Track"])
    end
  end
end
