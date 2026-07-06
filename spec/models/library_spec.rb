# frozen_string_literal: true

require "rails_helper"

RSpec.describe Library, type: :model do
  describe ".matching" do
    it "liefert Libraries, deren Stichwort case-insensitive im Namen vorkommt" do
      blues = Library.create!(name: "Blues", keyword: "blues")
      Library.create!(name: "Fusion", keyword: "fusion")

      expect(Library.matching("RSpec Blues Abend")).to eq([blues])
    end

    it "liefert mehrere Libraries, wenn mehrere Stichwoerter im Namen vorkommen" do
      blues = Library.create!(name: "Blues", keyword: "blues")
      fusion = Library.create!(name: "Fusion", keyword: "fusion")

      expect(Library.matching("RSpec Blues Fusion Night")).to contain_exactly(blues, fusion)
    end

    it "liefert ein leeres Array, wenn kein Stichwort passt" do
      Library.create!(name: "Blues", keyword: "blues")

      expect(Library.matching("RSpec Deep House Vibes")).to eq([])
    end
  end
end
