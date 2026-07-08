# frozen_string_literal: true

require "rails_helper"

RSpec.describe RelatedTracksFinder do
  def create_track(name)
    album = Album.create!(name: "Album #{name}", spotify_id: "alb-rtf-#{name}")
    Track.create!(name: name, spotify_id: "trk-rtf-#{name}", album: album, duration_ms: 200_000)
  end

  it "findet Tracks mit gemeinsamem Tag, sortiert nach Naehe der Staerke" do
    origin = create_track("Origin")
    close_match = create_track("Close Match")
    far_match = create_track("Far Match")
    category = Category.create!(name: "RSpec Emotion RTF")
    tag = category.tags.create!(name: "RSpec Froehlich", aliases: "x")

    TrackTag.create!(track: origin, tag: tag, strength: 8)
    TrackTag.create!(track: close_match, tag: tag, strength: 9)
    TrackTag.create!(track: far_match, tag: tag, strength: 2)

    results = RelatedTracksFinder.new(origin).call

    expect(results.map { |r| r[:track] }).to eq([close_match, far_match])
    expect(results.first[:score]).to be > results.second[:score]
  end

  it "ignoriert Tracks ohne gemeinsames Tag" do
    origin = create_track("Origin 2")
    unrelated = create_track("Unrelated")
    category = Category.create!(name: "RSpec Emotion RTF 2")
    tag = category.tags.create!(name: "RSpec Traurig RTF", aliases: "x")
    TrackTag.create!(track: origin, tag: tag, strength: 5)

    results = RelatedTracksFinder.new(origin).call

    expect(results.map { |r| r[:track] }).to_not include(unrelated)
  end

  it "schliesst sich selbst aus" do
    origin = create_track("Origin 3")
    category = Category.create!(name: "RSpec Emotion RTF 3")
    tag = category.tags.create!(name: "RSpec Tag RTF 3", aliases: "x")
    TrackTag.create!(track: origin, tag: tag, strength: 5)

    results = RelatedTracksFinder.new(origin).call

    expect(results.map { |r| r[:track] }).to_not include(origin)
  end

  it "liefert eine leere Liste, wenn der Ausgangstrack keine Tags hat" do
    origin = create_track("Origin 4")

    expect(RelatedTracksFinder.new(origin).call).to eq([])
  end

  describe "category_ids" do
    it "beruecksichtigt nur gemeinsame Tags aus den gewaehlten Kategorien" do
      origin = create_track("Origin 5")
      match_in_category = create_track("Match In Category")
      match_outside_category = create_track("Match Outside Category")
      emotion = Category.create!(name: "RSpec Emotion RTF 5")
      quality = Category.create!(name: "RSpec Qualitaet RTF 5")
      emotion_tag = emotion.tags.create!(name: "RSpec Froehlich RTF 5", aliases: "x")
      quality_tag = quality.tags.create!(name: "RSpec Tanzbar RTF 5", aliases: "y")

      TrackTag.create!(track: origin, tag: emotion_tag, strength: 5)
      TrackTag.create!(track: origin, tag: quality_tag, strength: 5)
      TrackTag.create!(track: match_in_category, tag: emotion_tag, strength: 5)
      TrackTag.create!(track: match_outside_category, tag: quality_tag, strength: 5)

      results = RelatedTracksFinder.new(origin, category_ids: [emotion.id]).call

      expect(results.map { |r| r[:track] }).to include(match_in_category)
      expect(results.map { |r| r[:track] }).to_not include(match_outside_category)
    end

    it "beruecksichtigt alle Kategorien, wenn keine gewaehlt ist" do
      origin = create_track("Origin 6")
      match = create_track("Match 6")
      category = Category.create!(name: "RSpec Emotion RTF 6")
      tag = category.tags.create!(name: "RSpec Tag RTF 6", aliases: "x")
      TrackTag.create!(track: origin, tag: tag, strength: 5)
      TrackTag.create!(track: match, tag: tag, strength: 5)

      results = RelatedTracksFinder.new(origin, category_ids: []).call

      expect(results.map { |r| r[:track] }).to include(match)
    end
  end
end
