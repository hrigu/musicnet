# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Artists", type: :request do
  fixtures :users

  before do
    sign_in users(:one)
    allow_any_instance_of(Track).to receive(:track_path).and_return(nil)
  end

  def create_artist_with_track
    album = Album.create!(name: "Album", spotify_id: "alb1")
    artist = Artist.create!(name: "Artist", spotify_id: "art1")
    Track.create!(name: "Track", spotify_id: "trk1", album: album, artists: [artist], duration_ms: 200_000)
    artist
  end

  describe "GET /artists" do
    it "liefert Erfolg" do
      create_artist_with_track

      get artists_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /artists/:id" do
    it "liefert Erfolg" do
      artist = create_artist_with_track

      get artist_path(artist)

      expect(response).to have_http_status(:success)
    end
  end
end
