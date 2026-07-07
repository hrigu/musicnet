# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tag, type: :model do
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
end
