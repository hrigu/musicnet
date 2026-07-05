require "rails_helper"

RSpec.describe TrackQuerySuggestions do
  describe ".for" do
    it "liefert ein leeres Array bei leerem Term" do
      expect(described_class.for("")).to eq([])
      expect(described_class.for(nil)).to eq([])
    end

    it "schlägt passende Feldnamen vor, wenn noch kein Doppelpunkt getippt wurde" do
      suggestions = described_class.for("gen")

      expect(suggestions).to include("genre:")
      expect(suggestions).to_not include("artist:")
    end

    it "schlägt passende Genre-Werte vor, wenn nach dem Feld gesucht wird" do
      album = Album.create!(name: "Album", spotify_id: "alb-sugg-genre")
      Track.create!(name: "A", spotify_id: "sugg-genre-a", album: album, genre: "RSpec Jazz")
      Track.create!(name: "B", spotify_id: "sugg-genre-b", album: album, genre: "RSpec Blues")

      suggestions = described_class.for("genre:ja")

      expect(suggestions).to eq(['genre:"RSpec Jazz"'])
    end

    it "setzt Werte mit Leerzeichen in Anführungszeichen" do
      Playlist.create!(name: "RSpec Zzyzx Abende", spotify_id: "pl-sugg")

      suggestions = described_class.for("playlist:zzyzx")

      expect(suggestions).to eq(['playlist:"RSpec Zzyzx Abende"'])
    end

    it "liefert ein leeres Array für ein unbekanntes Feld" do
      expect(described_class.for("composer:ba")).to eq([])
    end
  end
end
