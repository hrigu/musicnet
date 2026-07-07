# frozen_string_literal: true

require "rails_helper"

RSpec.describe TrackTag, type: :model do
  def build_track
    album = Album.create!(name: "RSpec Album", spotify_id: "rspec-tt-album-#{SecureRandom.hex(4)}")
    Track.create!(name: "RSpec Track", spotify_id: "rspec-tt-track-#{SecureRandom.hex(4)}",
                  album: album, duration_ms: 200_000)
  end

  it "verlangt eine Stärke zwischen 1 und 10" do
    category = Category.create!(name: "RSpec Kategorie")
    tag = Tag.create!(category: category, name: "RSpec Tag", aliases: "x")
    track = build_track

    expect(TrackTag.new(track: track, tag: tag, strength: 0)).not_to be_valid
    expect(TrackTag.new(track: track, tag: tag, strength: 11)).not_to be_valid
    expect(TrackTag.new(track: track, tag: tag, strength: 5)).to be_valid
  end

  it "verhindert doppelte Zuordnung desselben Tags zu demselben Track" do
    category = Category.create!(name: "RSpec Kategorie 2")
    tag = Tag.create!(category: category, name: "RSpec Tag 2", aliases: "x")
    track = build_track
    TrackTag.create!(track: track, tag: tag, strength: 5)

    expect(TrackTag.new(track: track, tag: tag, strength: 7)).not_to be_valid
  end
end
