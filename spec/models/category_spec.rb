# frozen_string_literal: true

require "rails_helper"

RSpec.describe Category, type: :model do
  it "verlangt einen eindeutigen Namen" do
    Category.create!(name: "RSpec Kategorie")

    expect(Category.new(name: "RSpec Kategorie")).not_to be_valid
  end

  it "löscht ihre Tags mit, wenn sie gelöscht wird" do
    category = Category.create!(name: "RSpec Kategorie 2")
    tag = Tag.create!(category: category, name: "RSpec Tag", aliases: "x")

    category.destroy

    expect(Tag.find_by(id: tag.id)).to be_nil
  end

  describe ".visible_for_assignment" do
    it "enthält Kategorien, die nicht für die Neuzuordnung ausgeblendet sind" do
      sichtbar = Category.create!(name: "RSpec Sichtbar")
      Category.create!(name: "RSpec Ausgeblendet", hidden_for_assignment: true)

      expect(Category.visible_for_assignment).to include(sichtbar)
    end

    it "schliesst ausgeblendete Kategorien aus" do
      ausgeblendet = Category.create!(name: "RSpec Ausgeblendet 2", hidden_for_assignment: true)

      expect(Category.visible_for_assignment).to_not include(ausgeblendet)
    end
  end

  describe "#color" do
    it "erlaubt einen leeren Wert" do
      expect(Category.new(name: "RSpec Farbe leer", color: "")).to be_valid
    end

    it "erlaubt einen 6-stelligen Hex-Wert mit und ohne #" do
      expect(Category.new(name: "RSpec Farbe 6a", color: "#4a90d9")).to be_valid
      expect(Category.new(name: "RSpec Farbe 6b", color: "4a90d9")).to be_valid
    end

    it "erlaubt einen 3-stelligen Hex-Wert (Kurzform)" do
      expect(Category.new(name: "RSpec Farbe 3", color: "#c9f")).to be_valid
    end

    it "lehnt einen ungültigen Wert ab" do
      expect(Category.new(name: "RSpec Farbe ungültig", color: "blue")).to_not be_valid
    end
  end
end
