# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "assign_track_tags rake task" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  before do
    Rake::Task["assign_track_tags"].reenable
  end

  def build_track(suffix)
    album = Album.create!(name: "RSpec Album #{suffix}", spotify_id: "rspec-att-album-#{suffix}")
    Track.create!(name: "RSpec Track #{suffix}", spotify_id: "rspec-att-track-#{suffix}",
                  album: album, duration_ms: 200_000)
  end

  it "ordnet einen Track einem Tag zu und berechnet die Stärke nach Häufigkeit" do
    category = Category.create!(name: "RSpec Emotion")
    tag = Tag.create!(category: category, name: "RSpec Traurig", aliases: "sad")

    playlist_a = Playlist.create!(name: "RSpec Fusion sad A", spotify_id: "rspec-att-pl-a")
    playlist_b = Playlist.create!(name: "RSpec Fusion sad B", spotify_id: "rspec-att-pl-b")
    track = build_track("once-then-twice")
    PlaylistTrack.create!(playlist: playlist_a, track: track)
    PlaylistTrack.create!(playlist: playlist_b, track: track)

    Rake::Task["assign_track_tags"].invoke

    track_tag = TrackTag.find_by(track: track, tag: tag)
    expect(track_tag.strength).to eq(7)
  end

  it "matched nicht faelschlich einen Teilstring ohne Wortgrenze (Salsadancers enthält 'sad')" do
    Category.create!(name: "RSpec Emotion 2").tags.create!(name: "RSpec Traurig 2", aliases: "sad")
    playlist = Playlist.create!(name: "RSpec Fusion Salsadancers", spotify_id: "rspec-att-pl-c")
    track = build_track("salsa")
    PlaylistTrack.create!(playlist: playlist, track: track)

    Rake::Task["assign_track_tags"].invoke

    expect(TrackTag.where(track: track).count).to eq(0)
  end

  it "entfernt eine veraltete Zuordnung, wenn der Track nicht mehr in einer matchenden Playlist ist" do
    category = Category.create!(name: "RSpec Emotion 3")
    tag = Tag.create!(category: category, name: "RSpec Traurig 3", aliases: "sad")
    playlist = Playlist.create!(name: "RSpec Fusion sad C", spotify_id: "rspec-att-pl-d")
    track = build_track("stale")
    playlist_track = PlaylistTrack.create!(playlist: playlist, track: track)
    Rake::Task["assign_track_tags"].invoke
    expect(TrackTag.find_by(track: track, tag: tag)).to be_present

    playlist_track.destroy
    Rake::Task["assign_track_tags"].reenable
    Rake::Task["assign_track_tags"].invoke

    expect(TrackTag.find_by(track: track, tag: tag)).to be_nil
  end

  it "laeuft beim zweiten Mal ohne Datenänderung idempotent (keine Aenderung an updated_at)" do
    category = Category.create!(name: "RSpec Emotion 4")
    playlist = Playlist.create!(name: "RSpec Fusion sad D", spotify_id: "rspec-att-pl-e")
    track = build_track("idempotent")
    PlaylistTrack.create!(playlist: playlist, track: track)
    category.tags.create!(name: "RSpec Traurig 4", aliases: "sad")
    Rake::Task["assign_track_tags"].invoke
    track_tag = TrackTag.find_by(track: track)
    updated_at_before = track_tag.updated_at

    Rake::Task["assign_track_tags"].reenable
    Rake::Task["assign_track_tags"].invoke

    expect(track_tag.reload.updated_at).to eq(updated_at_before)
  end

  describe "Auftrittsdatum-Tags (Intent 78)" do
    it "erkennt ein volles Datum am Anfang des Playlist-Namens" do
      playlist = Playlist.create!(name: "2023-12-01_RSpec Salsadancers", spotify_id: "rspec-att-date-a")
      track = build_track("date-full")
      PlaylistTrack.create!(playlist: playlist, track: track)

      Rake::Task["assign_track_tags"].invoke

      tag = Tag.joins(:category).find_by(name: "2023-12-01", categories: { name: "Auftrittsdatum" })
      expect(tag).to be_present
      expect(TrackTag.find_by(track: track, tag: tag)).to be_present
    end

    it "erkennt ein Jahr-Monat-Datum ohne Tag" do
      playlist = Playlist.create!(name: "2021-02-RSpec Fusion", spotify_id: "rspec-att-date-b")
      track = build_track("date-month")
      PlaylistTrack.create!(playlist: playlist, track: track)

      Rake::Task["assign_track_tags"].invoke

      expect(Tag.joins(:category).find_by(name: "2021-02", categories: { name: "Auftrittsdatum" })).to be_present
    end

    it "erkennt ein reines Jahr, getrennt durch Leerzeichen" do
      playlist = Playlist.create!(name: "2026 RSpec Fusionizers", spotify_id: "rspec-att-date-c")
      track = build_track("date-year")
      PlaylistTrack.create!(playlist: playlist, track: track)

      Rake::Task["assign_track_tags"].invoke

      expect(Tag.joins(:category).find_by(name: "2026", categories: { name: "Auftrittsdatum" })).to be_present
    end

    it "legt keinen Datums-Tag an, wenn der Name nicht mit einer Jahreszahl beginnt" do
      playlist = Playlist.create!(name: "RSpec Blues Piano", spotify_id: "rspec-att-date-d")
      track = build_track("date-none")
      PlaylistTrack.create!(playlist: playlist, track: track)

      Rake::Task["assign_track_tags"].invoke

      expect(TrackTag.joins(tag: :category).where(track: track, categories: { name: "Auftrittsdatum" })).to be_empty
    end

    it "entfernt die Zuordnung wieder, wenn keine Playlist mehr dieses Datum traegt" do
      playlist = Playlist.create!(name: "2024-05-03_RSpec Karl", spotify_id: "rspec-att-date-e")
      track = build_track("date-stale")
      PlaylistTrack.create!(playlist: playlist, track: track)
      Rake::Task["assign_track_tags"].invoke
      tag = Tag.joins(:category).find_by(name: "2024-05-03", categories: { name: "Auftrittsdatum" })
      expect(TrackTag.find_by(track: track, tag: tag)).to be_present

      playlist.update!(name: "RSpec Karl ohne Datum")
      Rake::Task["assign_track_tags"].reenable
      Rake::Task["assign_track_tags"].invoke

      expect(TrackTag.find_by(track: track, tag: tag)).to be_nil
    end
  end
end
