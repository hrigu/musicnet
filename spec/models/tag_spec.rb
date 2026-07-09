# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tag, type: :model do
  def build_track(name:)
    album = Album.create!(name: "RSpec Album #{name}", spotify_id: "rspec-tag-album-#{SecureRandom.hex(4)}")
    Track.create!(name:, spotify_id: "rspec-tag-track-#{SecureRandom.hex(4)}", album:, duration_ms: 200_000)
  end

  describe "#alias_list" do
    it "zerlegt die Komma-Liste in getrimmte Einzel-Aliase" do
      category = Category.create!(name: "RSpec Emotion")
      tag = Tag.create!(category: category, name: "RSpec Melancholisch",
                        aliases: "melancolic,  melancolia ,melancholia")

      expect(tag.alias_list).to eq(%w[melancolic melancolia melancholia])
    end
  end

  describe ".normalize" do
    it "ersetzt Apostrophe/Bindestriche/Unterstriche/Schrägstriche durch Leerzeichen statt sie zu entfernen" do
      expect(Tag.normalize("Rock'n'Roll")).to eq("rock n roll")
      expect(Tag.normalize("6/8-Takt")).to eq("6 8 takt")
      expect(Tag.normalize("blues_origininals_and_covers")).to eq("blues origininals and covers")
    end
  end

  describe "#matches_normalized_name?" do
    it "matched nicht bei einem Teilstring-Treffer ohne Wortgrenze (Salsadancers enthält 'sad')" do
      category = Category.create!(name: "RSpec Emotion 2")
      tag = Tag.create!(category: category, name: "RSpec Traurig", aliases: "sad")

      expect(tag.matches_normalized_name?(Tag.normalize("Fusion Salsadancers"))).to be false
    end

    it "matched einen echten Wort-Treffer" do
      category = Category.create!(name: "RSpec Emotion 3")
      tag = Tag.create!(category: category, name: "RSpec Traurig 2", aliases: "sad")

      expect(tag.matches_normalized_name?(Tag.normalize("Fusion sad"))).to be true
    end

    it "matched einen mehrwortigen Alias über eine normalisierte Bindestrich-Schreibweise hinweg" do
      category = Category.create!(name: "RSpec Anlass")
      tag = Tag.create!(category: category, name: "RSpec Fuse the Blues", aliases: "fuse the blues")

      expect(tag.matches_normalized_name?(Tag.normalize("2025-12-04_fuse_the_blues"))).to be true
    end
  end

  describe "validations" do
    it "verlangt eindeutige Namen innerhalb derselben Kategorie" do
      category = Category.create!(name: "RSpec Kategorie")
      Tag.create!(category: category, name: "RSpec Tag", aliases: "x")

      duplicate = Tag.new(category: category, name: "RSpec Tag", aliases: "y")

      expect(duplicate).not_to be_valid
    end

    it "erlaubt denselben Namen in unterschiedlichen Kategorien" do
      category_a = Category.create!(name: "RSpec Kategorie A")
      category_b = Category.create!(name: "RSpec Kategorie B")
      Tag.create!(category: category_a, name: "RSpec Gleicher Name", aliases: "x")

      other = Tag.new(category: category_b, name: "RSpec Gleicher Name", aliases: "y")

      expect(other).to be_valid
    end
  end

  describe ".assignable" do
    it "enthaelt nur Tags, die fuer neue Vergaben erlaubt sind" do
      category = Category.create!(name: "RSpec Kategorie assignable")
      erlaubtes_tag = Tag.create!(category:, name: "RSpec Erlaubt", aliases: "x")
      gesperrtes_tag = Tag.create!(category:, name: "RSpec Gesperrt", aliases: "y", assignable: false)

      expect(Tag.assignable).to include(erlaubtes_tag)
      expect(Tag.assignable).not_to include(gesperrtes_tag)
    end
  end

  describe ".recently_assigned_by" do
    it "liefert die letzten eindeutigen assignable Tags eines Users in absteigender Reihenfolge" do
      user = User.create!(email: "rspec-tags@example.com", password: "password123")
      category = Category.create!(name: "RSpec Kategorie letzte Tags")
      aelteres_tag = Tag.create!(category:, name: "RSpec Aelter", aliases: "a")
      neueres_tag = Tag.create!(category:, name: "RSpec Neuer", aliases: "b")

      TagAssignment.create!(user:, tag: neueres_tag, created_at: 1.hour.ago)
      TagAssignment.create!(user:, tag: aelteres_tag, created_at: 2.hours.ago)
      TagAssignment.create!(user:, tag: neueres_tag, created_at: 10.minutes.ago)

      expect(Tag.recently_assigned_by(user, limit: 5)).to eq([neueres_tag, aelteres_tag])
    end

    it "schliesst gesperrte Tags und Tags aus ausgeblendeten Kategorien aus" do
      user = User.create!(email: "rspec-tags-filter@example.com", password: "password123")
      sichtbare_kategorie = Category.create!(name: "RSpec Kategorie sichtbar")
      ausgeblendete_kategorie = Category.create!(name: "RSpec Kategorie hidden", hidden_for_assignment: true)
      erlaubtes_tag = Tag.create!(category: sichtbare_kategorie, name: "RSpec Sichtbar", aliases: "x")
      gesperrtes_tag = Tag.create!(category: sichtbare_kategorie, name: "RSpec Nicht erlaubt", aliases: "y",
                                   assignable: false)
      verborgenes_tag = Tag.create!(category: ausgeblendete_kategorie, name: "RSpec Versteckt", aliases: "z")

      TagAssignment.create!(user:, tag: verborgenes_tag, created_at: 5.minutes.ago)
      TagAssignment.create!(user:, tag: gesperrtes_tag, created_at: 4.minutes.ago)
      TagAssignment.create!(user:, tag: erlaubtes_tag, created_at: 3.minutes.ago)

      expect(Tag.recently_assigned_by(user, limit: 5)).to eq([erlaubtes_tag])
    end

    it "schliesst bereits am Track vorhandene Tags optional aus" do
      user = User.create!(email: "rspec-tags-exclude@example.com", password: "password123")
      category = Category.create!(name: "RSpec Kategorie Exclude")
      vorhandenes_tag = Tag.create!(category:, name: "RSpec Vorhanden", aliases: "x")
      anderes_tag = Tag.create!(category:, name: "RSpec Anderes", aliases: "y")
      track = build_track(name: "RSpec Track mit Tag")
      TrackTag.create!(track:, tag: vorhandenes_tag, strength: 5)

      TagAssignment.create!(user:, tag: vorhandenes_tag, created_at: 2.minutes.ago)
      TagAssignment.create!(user:, tag: anderes_tag, created_at: 1.minute.ago)

      expect(Tag.recently_assigned_by(user, limit: 5, exclude_track: track)).to eq([anderes_tag])
    end
  end
end
