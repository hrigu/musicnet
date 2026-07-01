# frozen_string_literal: true

require "rails_helper"

RSpec.describe Album, type: :model do
  describe "#artists" do
    it "liefert jeden Artist nur einmal, auch bei mehreren gemeinsamen Tracks" do
      album = Album.create!(name: "A Go Go", spotify_id: "alb1")
      artist = Artist.create!(name: "John Scofield", spotify_id: "art1")
      Track.create!(name: "Track 1", spotify_id: "trk1", album: album, artists: [artist])
      Track.create!(name: "Track 2", spotify_id: "trk2", album: album, artists: [artist])

      expect(album.artists).to eq([artist])
    end
  end
end
