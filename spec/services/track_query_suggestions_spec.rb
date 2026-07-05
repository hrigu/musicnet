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

    it "bleibt bei einem gerade getippten oeffnenden Anfuehrungszeichen bestehen (Bugfix)" do
      Artist.create!(name: "RSpec Zzyzx Cotton", spotify_id: "art-sugg-quote")

      suggestions = described_class.for('artist:"')

      expect(suggestions).to include('artist:"RSpec Zzyzx Cotton"')
    end

    it "grenzt Vorschlaege nach der Anfuehrung weiter ein (Bugfix)" do
      match = Artist.create!(name: "RSpec Zzyzx Cotton", spotify_id: "art-sugg-quote-match")
      Artist.create!(name: "RSpec Andere Band", spotify_id: "art-sugg-quote-miss")

      suggestions = described_class.for('artist:"zzyzx')

      expect(suggestions).to eq(["artist:\"#{match.name}\""])
    end

    it "schlaegt fuer den zweiten Wert einer Komma-Liste vor und behaelt den ersten (Bugfix)" do
      Artist.create!(name: "RSpec Zzyzx Hubert", spotify_id: "art-sugg-list-b")

      # "aaa" simuliert einen bereits getippten ersten Wert (ohne Leerzeichen, so wie ihn das
      # JS als einzelnes Token an den Endpoint schickt) - er muss im Vorschlag erhalten bleiben.
      suggestions = described_class.for("artist:aaa,zzyzx")

      expect(suggestions).to eq(['artist:aaa,"RSpec Zzyzx Hubert"'])
    end

    it "schlägt nur Playlists der aktiven Kategorie vor, wenn ein Filter gesetzt ist (Intent 55)" do
      Playlist.create!(name: "RSpec Zzyzx Blues Abend", spotify_id: "pl-sugg-cat-blues")
      Playlist.create!(name: "RSpec Zzyzx Fusion Abend", spotify_id: "pl-sugg-cat-fusion")

      suggestions = described_class.for("playlist:zzyzx", "fusion")

      expect(suggestions).to eq(['playlist:"RSpec Zzyzx Fusion Abend"'])
    end

    it "filtert Playlist-Vorschläge nicht ohne Kategorie-Filter (Intent 55)" do
      Playlist.create!(name: "RSpec Zzyzy Blues", spotify_id: "pl-sugg-nocat-blues")
      Playlist.create!(name: "RSpec Zzyzy Fusion", spotify_id: "pl-sugg-nocat-fusion")

      suggestions = described_class.for("playlist:zzyzy")

      expect(suggestions).to contain_exactly(
        'playlist:"RSpec Zzyzy Blues"', 'playlist:"RSpec Zzyzy Fusion"'
      )
    end

    it "schlägt nur Artists der aktiven Kategorie vor, wenn ein Filter gesetzt ist (Intent 55)" do
      album = Album.create!(name: "Album", spotify_id: "alb-sugg-cat-art")
      blues_artist = Artist.create!(name: "RSpec Zzyzw Blues Artist", spotify_id: "art-sugg-cat-blues")
      fusion_artist = Artist.create!(name: "RSpec Zzyzw Fusion Artist", spotify_id: "art-sugg-cat-fusion")
      blues_track = Track.create!(name: "A", spotify_id: "trk-sugg-cat-blues", album: album,
                                  artists: [blues_artist], duration_ms: 200_000)
      fusion_track = Track.create!(name: "B", spotify_id: "trk-sugg-cat-fusion", album: album,
                                   artists: [fusion_artist], duration_ms: 200_000)
      blues_playlist = Playlist.create!(name: "RSpec Blues Session", spotify_id: "pl-sugg-cat-art-blues")
      fusion_playlist = Playlist.create!(name: "RSpec Fusion Session", spotify_id: "pl-sugg-cat-art-fusion")
      PlaylistTrack.create!(playlist: blues_playlist, track: blues_track, added_at: Time.current)
      PlaylistTrack.create!(playlist: fusion_playlist, track: fusion_track, added_at: Time.current)

      suggestions = described_class.for("artist:zzyzw", "fusion")

      expect(suggestions).to eq(['artist:"RSpec Zzyzw Fusion Artist"'])
    end

    it "schlägt nur Genres der aktiven Kategorie vor, wenn ein Filter gesetzt ist (Intent 55)" do
      album = Album.create!(name: "Album", spotify_id: "alb-sugg-cat-genre")
      blues_track = Track.create!(name: "A", spotify_id: "trk-sugg-cat-genre-blues", album: album,
                                  genre: "RSpec Zzyzv Delta Blues")
      fusion_track = Track.create!(name: "B", spotify_id: "trk-sugg-cat-genre-fusion", album: album,
                                   genre: "RSpec Zzyzv Jazz Fusion")
      blues_playlist = Playlist.create!(name: "RSpec Blues Genre Session", spotify_id: "pl-sugg-cat-genre-blues")
      fusion_playlist = Playlist.create!(name: "RSpec Fusion Genre Session", spotify_id: "pl-sugg-cat-genre-fusion")
      PlaylistTrack.create!(playlist: blues_playlist, track: blues_track, added_at: Time.current)
      PlaylistTrack.create!(playlist: fusion_playlist, track: fusion_track, added_at: Time.current)

      suggestions = described_class.for("genre:zzyzv", "fusion")

      expect(suggestions).to eq(['genre:"RSpec Zzyzv Jazz Fusion"'])
    end
  end
end
