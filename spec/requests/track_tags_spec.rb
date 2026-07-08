# frozen_string_literal: true

require "rails_helper"

RSpec.describe "TrackTags", type: :request do
  fixtures :users

  before { sign_in users(:one) }

  def create_track(spotify_id: "trk-tt-1")
    album = Album.create!(name: "Album", spotify_id: "alb-#{spotify_id}")
    Track.create!(name: "Track", spotify_id: spotify_id, album: album, duration_ms: 200_000)
  end

  describe "POST /track_tags" do
    it "verknüpft einen bestehenden Tag (per tag_id) mit dem Track" do
      track = create_track
      category = Category.create!(name: "RSpec Emotion Assign")
      tag = category.tags.create!(name: "RSpec Traurig Assign", aliases: "x")

      post track_tags_path, params: { track_id: track.id, tag_id: tag.id, strength: 7 }

      expect(response).to redirect_to(track_path(track))
      track_tag = TrackTag.find_by(track: track, tag: tag)
      expect(track_tag.strength).to eq(7)
    end

    it "legt einen neuen Tag in der gewählten Kategorie an und verknüpft ihn" do
      track = create_track(spotify_id: "trk-tt-2")
      category = Category.create!(name: "RSpec Emotion Neu")

      post track_tags_path, params: { track_id: track.id, tag_name: "RSpec Brandneu", category_id: category.id, strength: 4 }

      tag = Tag.find_by(name: "RSpec Brandneu", category: category)
      expect(tag).to be_present
      expect(TrackTag.find_by(track: track, tag: tag).strength).to eq(4)
    end

    it "verwendet einen schon bestehenden Tag in der Kategorie statt eines Duplikats" do
      track = create_track(spotify_id: "trk-tt-3")
      category = Category.create!(name: "RSpec Emotion Dup")
      existing = category.tags.create!(name: "RSpec Schon Da", aliases: "x")

      post track_tags_path, params: { track_id: track.id, tag_name: "RSpec Schon Da", category_id: category.id, strength: 5 }

      expect(Tag.where(name: "RSpec Schon Da", category: category).count).to eq(1)
      expect(TrackTag.find_by(track: track, tag: existing)).to be_present
    end

    it "aktualisiert die Stärke, wenn der Tag schon verknüpft ist, statt einen Fehler zu werfen" do
      track = create_track(spotify_id: "trk-tt-4")
      category = Category.create!(name: "RSpec Emotion Update")
      tag = category.tags.create!(name: "RSpec Update Mich", aliases: "x")
      TrackTag.create!(track: track, tag: tag, strength: 5)

      post track_tags_path, params: { track_id: track.id, tag_id: tag.id, strength: 9 }

      expect(TrackTag.find_by(track: track, tag: tag).strength).to eq(9)
      expect(TrackTag.where(track: track, tag: tag).count).to eq(1)
    end

    it "zeigt eine Fehlermeldung bei ungültiger Stärke, ohne eine Zuordnung anzulegen" do
      track = create_track(spotify_id: "trk-tt-5")
      category = Category.create!(name: "RSpec Emotion Invalid")
      tag = category.tags.create!(name: "RSpec Invalid", aliases: "x")

      post track_tags_path, params: { track_id: track.id, tag_id: tag.id, strength: 99 }

      expect(response).to redirect_to(track_path(track))
      follow_redirect!
      expect(response.body).to include("not included in the list")
      expect(TrackTag.find_by(track: track, tag: tag)).to be_nil
    end

    it "zeigt eine Fehlermeldung, wenn weder Tag noch Name+Kategorie angegeben sind" do
      track = create_track(spotify_id: "trk-tt-6")

      post track_tags_path, params: { track_id: track.id, strength: 5 }

      expect(response).to redirect_to(track_path(track))
      expect(TrackTag.where(track: track).count).to eq(0)
    end
  end

  describe "PATCH /track_tags/:id" do
    it "aktualisiert die Stärke einer bestehenden Zuordnung" do
      track = create_track(spotify_id: "trk-tt-8")
      category = Category.create!(name: "RSpec Emotion Patch")
      tag = category.tags.create!(name: "RSpec Patch Mich", aliases: "x")
      track_tag = TrackTag.create!(track: track, tag: tag, strength: 3)

      patch track_tag_path(track_tag), params: { strength: 8 }

      expect(response).to redirect_to(track_path(track))
      expect(track_tag.reload.strength).to eq(8)
    end

    it "aktualisiert per Turbo-Stream, ohne die Seite neu zu laden" do
      track = create_track(spotify_id: "trk-tt-9")
      category = Category.create!(name: "RSpec Emotion Patch Stream")
      tag = category.tags.create!(name: "RSpec Patch Stream", aliases: "x")
      track_tag = TrackTag.create!(track: track, tag: tag, strength: 3)

      patch track_tag_path(track_tag), params: { strength: 8 }, as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("RSpec Patch Stream · 8")
      expect(track_tag.reload.strength).to eq(8)
    end

    it "lässt eine ungültige Stärke unangewendet und zeigt das Formular mit Fehler erneut" do
      track = create_track(spotify_id: "trk-tt-10")
      category = Category.create!(name: "RSpec Emotion Patch Invalid")
      tag = category.tags.create!(name: "RSpec Patch Invalid", aliases: "x")
      track_tag = TrackTag.create!(track: track, tag: tag, strength: 3)

      patch track_tag_path(track_tag), params: { strength: 99 }, as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("not included in the list")
      expect(track_tag.reload.strength).to eq(3)
    end
  end

  describe "DELETE /track_tags/:id" do
    it "entfernt die Zuordnung, lässt den Tag selbst aber bestehen" do
      track = create_track(spotify_id: "trk-tt-7")
      category = Category.create!(name: "RSpec Emotion Delete")
      tag = category.tags.create!(name: "RSpec Löschen", aliases: "x")
      track_tag = TrackTag.create!(track: track, tag: tag, strength: 5)

      delete track_tag_path(track_tag)

      expect(response).to redirect_to(track_path(track))
      expect(TrackTag.find_by(id: track_tag.id)).to be_nil
      expect(Tag.find_by(id: tag.id)).to be_present
    end
  end
end
