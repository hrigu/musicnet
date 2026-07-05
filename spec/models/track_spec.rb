# frozen_string_literal: true

require "rails_helper"

RSpec.describe Track, type: :model do
  let(:downloads_dir) { Rails.root.join("downloads/tracks") }

  # Legt eine echte Datei ins Download-Verzeichnis und räumt sie danach wieder weg —
  # das Pfad-Matching wird gegen das Dateisystem getestet, nicht gegen Stubs.
  def with_download_file(file_name)
    FileUtils.mkdir_p(downloads_dir)
    FileUtils.touch(downloads_dir.join(file_name))
    yield
  ensure
    FileUtils.rm_f(downloads_dir.join(file_name))
  end

  describe "#dauer" do
    it "formatiert duration_ms als MM:SS" do
      track = Track.new(duration_ms: 125_000)

      expect(track.dauer).to eq("02:05")
    end
  end

  describe "#af, #energy, #tempo" do
    it "liest audio_features direkt als Hash in ein OpenStruct" do
      track = Track.new(audio_features: { "energy" => 0.7, "tempo" => 120.5 })

      expect(track.energy).to eq(0.7)
      expect(track.tempo).to eq(120.5)
    end

    it "gibt nil zurück, wenn audio_features leer ist" do
      track = Track.new(audio_features: nil)

      expect(track.af).to be_nil
      expect(track.energy).to be_nil
      expect(track.tempo).to be_nil
    end
  end

  describe ".preload_track_paths" do
    it "setzt track_path für alle Tracks mit einem einzigen Verzeichnis-Scan" do
      found = Track.new(name: "RSpec Song: Live")
      missing = Track.new(name: "RSpec Nicht Vorhanden")
      file_name = "RSpec Artist - RSpec Song- Live.m4a"

      with_download_file(file_name) do
        Track.preload_track_paths([found, missing])
      end

      # Datei ist beim Zugriff bereits gelöscht: liefert track_path den Pfad trotzdem,
      # wurde er beim Preload aufgelöst und nicht durch einen erneuten Verzeichnis-Scan.
      aggregate_failures do
        expect(found.track_path).to eq(downloads_dir.join(file_name).to_s)
        expect(missing.track_path).to be_nil
      end
    end

    it "memoisiert auch nicht gefundene Pfade" do
      missing = Track.new(name: "RSpec Nicht Vorhanden")

      Track.preload_track_paths([missing])

      # Eine erst nach dem Preload erstellte Datei darf nicht mehr gefunden werden,
      # sonst hätte track_path erneut das Verzeichnis gelesen.
      with_download_file("RSpec Artist - RSpec Nicht Vorhanden.m4a") do
        expect(missing.track_path).to be_nil
      end
    end
  end

  describe ".sorted" do
    def create_track(name:, duration_ms:, genre:, popularity:, release_date:, spotify_id:,
                     energy: nil, tempo: nil)
      album = Album.create!(name: "Album #{spotify_id}", spotify_id: "alb-#{spotify_id}", release_date: release_date)
      Track.create!(name: name, spotify_id: spotify_id, album: album, duration_ms: duration_ms,
                    genre: genre, popularity: popularity,
                    audio_features: { "energy" => energy, "tempo" => tempo })
    end

    before do
      create_track(name: "B Track", duration_ms: 200_000, genre: "Blues", popularity: 50,
                   release_date: "2020-01-01", spotify_id: "sort-b", energy: 0.5, tempo: 90.0)
      create_track(name: "A Track", duration_ms: 100_000, genre: "Fusion", popularity: 80,
                   release_date: "2010-01-01", spotify_id: "sort-a", energy: 0.9, tempo: 130.0)
      create_track(name: "C Track", duration_ms: 300_000, genre: "Jazz", popularity: 20,
                   release_date: "2030-01-01", spotify_id: "sort-c", energy: 0.1, tempo: 110.0)
    end

    it "sortiert nach Name aufsteigend (Default)" do
      expect(described_class.sorted(nil, nil).pluck(:name)).to eq(["A Track", "B Track", "C Track"])
    end

    it "sortiert nach Dauer" do
      expect(described_class.sorted("duration_ms", "asc").pluck(:name)).to eq(["A Track", "B Track", "C Track"])
      expect(described_class.sorted("duration_ms", "desc").pluck(:name)).to eq(["C Track", "B Track", "A Track"])
    end

    it "sortiert nach Genre" do
      expect(described_class.sorted("genre", "asc").pluck(:name)).to eq(["B Track", "A Track", "C Track"])
    end

    it "sortiert nach Bekanntheit (popularity)" do
      expect(described_class.sorted("popularity", "desc").pluck(:name)).to eq(["A Track", "B Track", "C Track"])
    end

    it "sortiert nach Album-Release-Date" do
      expect(described_class.sorted("release_date", "asc").pluck(:name)).to eq(["A Track", "B Track", "C Track"])
    end

    it "fällt bei unbekannter Spalte auf Name zurück, ohne Fehler" do
      expect(described_class.sorted("does_not_exist", "asc").pluck(:name)).to eq(["A Track", "B Track", "C Track"])
    end

    it "fällt bei unbekannter Richtung auf aufsteigend zurück, behält aber die Spalte" do
      expect(described_class.sorted("duration_ms", "sideways").pluck(:name)).to eq(["A Track", "B Track", "C Track"])
    end

    it "sortiert nach Energie (aus dem audio_features-JSON, ohne eigene DB-Spalte)" do
      expect(described_class.sorted("energy", "desc").pluck(:name)).to eq(["A Track", "B Track", "C Track"])
    end

    it "sortiert nach Tempo (aus dem audio_features-JSON, ohne eigene DB-Spalte)" do
      expect(described_class.sorted("tempo", "asc").pluck(:name)).to eq(["B Track", "C Track", "A Track"])
    end
  end

  describe ".search" do
    def create_track(name:, spotify_id:, genre: nil, album_name: "Album", artist_names: ["Artist"])
      album = Album.create!(name: album_name, spotify_id: "alb-#{spotify_id}")
      artists = artist_names.map { |n| Artist.create!(name: n, spotify_id: "art-#{n.parameterize}-#{spotify_id}") }
      Track.create!(name: name, spotify_id: spotify_id, album: album, artists: artists,
                    duration_ms: 200_000, genre: genre)
    end

    it "findet Tracks über den Namen, unabhängig von Gross-/Kleinschreibung" do
      match = create_track(name: "RSpec Blues Shuffle", spotify_id: "search-name")
      create_track(name: "Andere Nummer", spotify_id: "search-name-miss")

      expect(described_class.search("blues shuffle").to_a).to eq([match])
    end

    it "findet Tracks über den Künstlernamen" do
      match = create_track(name: "Irrelevant", spotify_id: "search-artist", artist_names: ["RSpec Fusion Combo"])
      create_track(name: "Anderer Track", spotify_id: "search-artist-miss", artist_names: ["Andere Band"])

      expect(described_class.search("fusion combo").to_a).to eq([match])
    end

    it "findet Tracks über den Album-Namen" do
      match = create_track(name: "Irrelevant", spotify_id: "search-album", album_name: "RSpec Live Session")
      create_track(name: "Anderer Track", spotify_id: "search-album-miss", album_name: "Anderes Album")

      expect(described_class.search("live session").to_a).to eq([match])
    end

    it "findet Tracks über das Genre" do
      match = create_track(name: "Irrelevant", spotify_id: "search-genre", genre: "RSpec Fusion")
      create_track(name: "Anderer Track", spotify_id: "search-genre-miss", genre: "Jazz")

      expect(described_class.search("fusion").to_a).to eq([match])
    end

    it "liefert einen Track mit mehreren Künstlern nur einmal" do
      match = create_track(name: "RSpec Multi Artist", spotify_id: "search-distinct",
                           artist_names: ["RSpec Artist Eins", "RSpec Artist Zwei"])

      expect(described_class.search("rspec multi artist").to_a).to eq([match])
    end

    it "liefert die unveränderte Relation bei leerem Suchbegriff" do
      create_track(name: "RSpec Track Ohne Suche", spotify_id: "search-blank")

      expect(described_class.search("").count).to eq(described_class.count)
      expect(described_class.search(nil).count).to eq(described_class.count)
    end
  end

  describe ".search_query" do
    def create_track(name:, spotify_id:, genre: nil, tempo: nil, artist_names: [])
      album = Album.create!(name: "Album #{spotify_id}", spotify_id: "alb-#{spotify_id}")
      artists = artist_names.map { |n| Artist.create!(name: n, spotify_id: "art-#{n.parameterize}-#{spotify_id}") }
      Track.create!(name: name, spotify_id: spotify_id, album: album, genre: genre, artists: artists,
                    audio_features: tempo ? { "tempo" => tempo } : nil)
    end

    def add_to_playlist(track, playlist_name:, spotify_id:)
      playlist = Playlist.find_or_create_by!(name: playlist_name) { |p| p.spotify_id = spotify_id }
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
    end

    it "verhält sich bei reinem Freitext wie die bestehende Volltextsuche" do
      match = create_track(name: "RSpec Blues Shuffle", spotify_id: "sq-freitext-a")
      create_track(name: "Andere Nummer", spotify_id: "sq-freitext-b")

      expect(described_class.search_query("blues shuffle").to_a).to eq([match])
    end

    it "filtert nach einem einzelnen Feld" do
      match = create_track(name: "A", spotify_id: "sq-single-a", genre: "RSpec Jazz")
      create_track(name: "B", spotify_id: "sq-single-b", genre: "RSpec Blues")

      expect(described_class.search_query("genre:jazz").to_a).to eq([match])
    end

    it "verknüpft mehrere Kriterien mit UND" do
      match = create_track(name: "A", spotify_id: "sq-and-a", genre: "RSpec Jazz", tempo: 90.0)
      create_track(name: "B", spotify_id: "sq-and-b", genre: "RSpec Jazz", tempo: 140.0)
      create_track(name: "C", spotify_id: "sq-and-c", genre: "RSpec Blues", tempo: 90.0)

      result = described_class.search_query("genre:jazz bpm:80..100")

      expect(result.to_a).to eq([match])
    end

    it "verknüpft wiederholte Vorkommen desselben Feldes als Schnittmenge (Playlist-UND)" do
      both = create_track(name: "A", spotify_id: "sq-playlist-and-a")
      add_to_playlist(both, playlist_name: "RSpec Fusion Abende SQ", spotify_id: "sq-pl-fusion")
      add_to_playlist(both, playlist_name: "RSpec Blues Session SQ", spotify_id: "sq-pl-blues")
      only_one = create_track(name: "B", spotify_id: "sq-playlist-and-b")
      add_to_playlist(only_one, playlist_name: "RSpec Fusion Abende SQ", spotify_id: "sq-pl-fusion")

      result = described_class.search_query('playlist:"Fusion Abende SQ" playlist:"Blues Session SQ"')

      expect(result.to_a).to eq([both])
    end

    it "liefert die unveränderte Relation bei leerem Suchbegriff" do
      create_track(name: "RSpec Ohne Suche", spotify_id: "sq-blank")

      expect(described_class.search_query("").count).to eq(described_class.count)
      expect(described_class.search_query(nil).count).to eq(described_class.count)
    end

    it "schliesst Treffer bei Negation aus" do
      match = create_track(name: "A", spotify_id: "sq-negate-a", genre: "RSpec Jazz")
      create_track(name: "B", spotify_id: "sq-negate-b", genre: "RSpec Blues")

      result = described_class.search_query("-genre:blues")

      expect(result.to_a).to include(match)
      expect(result.to_a).to_not include(described_class.find_by(spotify_id: "sq-negate-b"))
    end

    it "behandelt ein unbekanntes Feld als Freitext, ohne Fehler" do
      create_track(name: "Andere Nummer", spotify_id: "sq-unknown-field")

      expect { described_class.search_query("composer:Bach") }.to_not raise_error
      expect(described_class.search_query("composer:Bach").to_a).to eq([])
    end

    it "ignoriert einen ungültigen numerischen Wert, ohne Fehler" do
      match = create_track(name: "A", spotify_id: "sq-invalid-numeric-a", genre: "RSpec Jazz")
      create_track(name: "B", spotify_id: "sq-invalid-numeric-b", genre: "RSpec Blues")

      result = described_class.search_query("genre:jazz bpm:abc")

      expect(result.to_a).to eq([match])
    end
  end

  describe ".by_genre" do
    def create_track(name:, spotify_id:, genre:)
      album = Album.create!(name: "Album", spotify_id: "alb-#{spotify_id}")
      Track.create!(name: name, spotify_id: spotify_id, album: album, genre: genre)
    end

    it "findet Tracks über einen Contains-Wert" do
      match = create_track(name: "A", spotify_id: "by-genre-a", genre: "RSpec Jazz")
      create_track(name: "B", spotify_id: "by-genre-b", genre: "RSpec Blues")

      result = described_class.by_genre(type: :contains, value: "jazz")

      expect(result.to_a).to eq([match])
    end

    it "findet Tracks über eine ODER-Liste" do
      jazz = create_track(name: "A", spotify_id: "by-genre-list-a", genre: "RSpec Jazz")
      fusion = create_track(name: "B", spotify_id: "by-genre-list-b", genre: "RSpec Fusion")
      create_track(name: "C", spotify_id: "by-genre-list-c", genre: "RSpec Blues")

      result = described_class.by_genre(type: :list, values: ["rspec jazz", "rspec fusion"])

      expect(result.to_a).to contain_exactly(jazz, fusion)
    end
  end

  describe ".by_album" do
    def create_track(name:, spotify_id:, album_name:)
      album = Album.create!(name: album_name, spotify_id: "alb-#{spotify_id}")
      Track.create!(name: name, spotify_id: spotify_id, album: album)
    end

    it "findet Tracks über einen Contains-Wert auf dem Album-Namen" do
      match = create_track(name: "A", spotify_id: "by-album-a", album_name: "RSpec Live Session")
      create_track(name: "B", spotify_id: "by-album-b", album_name: "RSpec Studio Album")

      result = described_class.by_album(type: :contains, value: "live session")

      expect(result.to_a).to eq([match])
    end

    it "findet Tracks über eine ODER-Liste" do
      live = create_track(name: "A", spotify_id: "by-album-list-a", album_name: "RSpec Live Session")
      studio = create_track(name: "B", spotify_id: "by-album-list-b", album_name: "RSpec Studio Album")
      create_track(name: "C", spotify_id: "by-album-list-c", album_name: "RSpec Andere Scheibe")

      result = described_class.by_album(type: :list, values: ["live session", "studio album"])

      expect(result.to_a).to contain_exactly(live, studio)
    end
  end

  describe ".by_artist" do
    def create_track(name:, spotify_id:, artist_names:)
      album = Album.create!(name: "Album", spotify_id: "alb-#{spotify_id}")
      artists = artist_names.map { |n| Artist.create!(name: n, spotify_id: "art-#{n.parameterize}-#{spotify_id}") }
      Track.create!(name: name, spotify_id: spotify_id, album: album, artists: artists)
    end

    it "findet Tracks über einen Contains-Wert auf dem Künstlernamen" do
      match = create_track(name: "A", spotify_id: "by-artist-a", artist_names: ["RSpec Miles Davis"])
      create_track(name: "B", spotify_id: "by-artist-b", artist_names: ["RSpec John Coltrane"])

      result = described_class.by_artist(type: :contains, value: "miles davis")

      expect(result.to_a).to eq([match])
    end

    it "findet Tracks über eine ODER-Liste" do
      davis = create_track(name: "A", spotify_id: "by-artist-list-a", artist_names: ["RSpec Miles Davis"])
      coltrane = create_track(name: "B", spotify_id: "by-artist-list-b", artist_names: ["RSpec John Coltrane"])
      create_track(name: "C", spotify_id: "by-artist-list-c", artist_names: ["RSpec Andere Band"])

      result = described_class.by_artist(type: :list, values: ["miles davis", "john coltrane"])

      expect(result.to_a).to contain_exactly(davis, coltrane)
    end

    it "liefert bei zweifacher Anwendung die Schnittmenge, kein Join-Alias-Konflikt (Design-" \
       "Entscheidung Intent 43: Subquery statt direktem Join)" do
      duo_track = create_track(name: "A", spotify_id: "by-artist-and-a",
                               artist_names: ["RSpec Miles Davis", "RSpec John Coltrane"])
      create_track(name: "B", spotify_id: "by-artist-and-b", artist_names: ["RSpec Miles Davis"])

      result = described_class.by_artist(type: :contains, value: "miles davis")
                              .by_artist(type: :contains, value: "john coltrane")

      expect(result.to_a).to eq([duo_track])
    end
  end

  describe ".by_playlist" do
    def create_track(name:, spotify_id:)
      album = Album.create!(name: "Album", spotify_id: "alb-#{spotify_id}")
      Track.create!(name: name, spotify_id: spotify_id, album: album)
    end

    def add_to_playlist(track, playlist_name:, spotify_id:)
      playlist = Playlist.find_or_create_by!(name: playlist_name) { |p| p.spotify_id = spotify_id }
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
    end

    it "findet Tracks über einen Contains-Wert auf dem Playlist-Namen" do
      match = create_track(name: "A", spotify_id: "by-playlist-a")
      add_to_playlist(match, playlist_name: "RSpec Fusion Abende", spotify_id: "pl-fusion")
      miss = create_track(name: "B", spotify_id: "by-playlist-b")
      add_to_playlist(miss, playlist_name: "RSpec Blues Session", spotify_id: "pl-blues")

      result = described_class.by_playlist(type: :contains, value: "fusion abende")

      expect(result.to_a).to eq([match])
    end

    it "liefert bei zweifacher Anwendung die Schnittmenge (Playlist-UND, Intent 43)" do
      both = create_track(name: "A", spotify_id: "by-playlist-and-a")
      add_to_playlist(both, playlist_name: "RSpec Fusion Abende Und", spotify_id: "pl-fusion-and")
      add_to_playlist(both, playlist_name: "RSpec Blues Session Und", spotify_id: "pl-blues-and")
      only_a = create_track(name: "B", spotify_id: "by-playlist-and-b")
      add_to_playlist(only_a, playlist_name: "RSpec Fusion Abende Und", spotify_id: "pl-fusion-and")

      result = described_class.by_playlist(type: :contains, value: "fusion abende und")
                              .by_playlist(type: :contains, value: "blues session und")

      expect(result.to_a).to eq([both])
    end
  end

  describe ".by_tempo" do
    def create_track(name:, spotify_id:, tempo:)
      album = Album.create!(name: "Album", spotify_id: "alb-#{spotify_id}")
      Track.create!(name: name, spotify_id: spotify_id, album: album, audio_features: { "tempo" => tempo })
    end

    before do
      @slow = create_track(name: "Slow", spotify_id: "tempo-slow", tempo: 80.0)
      @mid = create_track(name: "Mid", spotify_id: "tempo-mid", tempo: 110.0)
      @fast = create_track(name: "Fast", spotify_id: "tempo-fast", tempo: 140.0)
    end

    it "filtert exakt bei einem einfachen Wert" do
      expect(described_class.by_tempo(type: :contains, value: "110").to_a).to eq([@mid])
    end

    it "filtert per Range inklusive der Grenzen" do
      result = described_class.by_tempo(type: :range, min: "80", max: "110")

      expect(result.to_a).to contain_exactly(@slow, @mid)
    end
  end

  describe ".by_energy" do
    it "filtert exakt bei einem einfachen Wert" do
      album = Album.create!(name: "Album", spotify_id: "alb-energy")
      match = Track.create!(name: "A", spotify_id: "by-energy-a", album: album,
                            audio_features: { "energy" => 0.7 })
      Track.create!(name: "B", spotify_id: "by-energy-b", album: album, audio_features: { "energy" => 0.2 })

      expect(described_class.by_energy(type: :contains, value: "0.7").to_a).to eq([match])
    end
  end

  describe ".by_popularity" do
    def create_track(name:, spotify_id:, popularity:)
      album = Album.create!(name: "Album", spotify_id: "alb-#{spotify_id}")
      Track.create!(name: name, spotify_id: spotify_id, album: album, popularity: popularity)
    end

    before do
      @low = create_track(name: "Low", spotify_id: "pop-low", popularity: 20)
      @mid = create_track(name: "Mid", spotify_id: "pop-mid", popularity: 50)
      @high = create_track(name: "High", spotify_id: "pop-high", popularity: 80)
    end

    it "filtert exakt bei einem einfachen Wert" do
      expect(described_class.by_popularity(type: :contains, value: "50").to_a).to eq([@mid])
    end

    it "filtert per ODER-Liste" do
      result = described_class.by_popularity(type: :list, values: %w[20 80])

      expect(result.to_a).to contain_exactly(@low, @high)
    end

    it "filtert per Vergleichsoperator" do
      result = described_class.by_popularity(type: :comparison, operator: ">", value: "40")

      expect(result.to_a).to contain_exactly(@mid, @high)
    end
  end

  describe ".by_release_year" do
    def create_track(name:, spotify_id:, release_date:)
      album = Album.create!(name: "Album #{spotify_id}", spotify_id: "alb-#{spotify_id}", release_date: release_date)
      Track.create!(name: name, spotify_id: spotify_id, album: album)
    end

    before do
      @old = create_track(name: "Old", spotify_id: "year-old", release_date: "2005-06-01")
      @mid = create_track(name: "Mid", spotify_id: "year-mid", release_date: "2015-06-01")
      @new = create_track(name: "New", spotify_id: "year-new", release_date: "2023-06-01")
    end

    it "filtert exakt bei einem Jahr" do
      expect(described_class.by_release_year(type: :contains, value: "2015").to_a).to eq([@mid])
    end

    it "filtert per Range inklusive der Grenzen" do
      result = described_class.by_release_year(type: :range, min: "2010", max: "2020")

      expect(result.to_a).to eq([@mid])
    end

    it "filtert per Vergleichsoperator" do
      result = described_class.by_release_year(type: :comparison, operator: ">", value: "2010")

      expect(result.to_a).to contain_exactly(@mid, @new)
    end
  end

  describe ".for_index" do
    it "liefert streng geladene Tracks für den Index" do
      album = Album.create!(name: "Album", spotify_id: "alb-strict")
      track = Track.create!(name: "Track Strict", spotify_id: "trk-strict", album: album, duration_ms: 200_000)

      found = described_class.for_index.find_by!(spotify_id: track.spotify_id)

      expect(found.strict_loading?).to be(true)
      expect(found).to eq(track)
    end
  end

  describe ".for_show" do
    it "liefert streng geladene Tracks für die Show" do
      album = Album.create!(name: "Album", spotify_id: "alb-show-strict")
      artist = Artist.create!(name: "Artist", spotify_id: "art-show-strict")
      track = Track.create!(name: "Track Show Strict", spotify_id: "trk-show-strict",
                            album: album, artists: [artist], duration_ms: 200_000)

      found = described_class.for_show.find_by!(spotify_id: track.spotify_id)

      expect(found.strict_loading?).to be(true)
      expect(found).to eq(track)
    end
  end

  describe ".for_download" do
    it "liefert streng geladene Tracks für den Download" do
      album = Album.create!(name: "Album", spotify_id: "alb-download-strict")
      track = Track.create!(name: "Track Download Strict", spotify_id: "trk-download-strict",
                            album: album, duration_ms: 200_000)

      found = described_class.for_download.find { |entry| entry.spotify_id == track.spotify_id }

      expect(found.strict_loading?).to be(true)
      expect(found).to eq(track)
    end
  end

  describe "#track_path" do
    it "findet die passende, sanitisierte Datei im downloads/tracks-Verzeichnis" do
      track = Track.new(name: "RSpec Song: Live?")
      file_name = "RSpec Artist - RSpec Song- Live.m4a"

      with_download_file(file_name) do
        expect(track.track_path).to eq(downloads_dir.join(file_name).to_s)
      end
    end

    it "findet die Datei unabhängig von Gross-/Kleinschreibung (wie das frühere Glob auf macOS)" do
      track = Track.new(name: "RSpec Song Case")

      with_download_file("RSPEC ARTIST - RSPEC SONG CASE.M4A") do
        expect(track.track_path).to eq(downloads_dir.join("RSPEC ARTIST - RSPEC SONG CASE.M4A").to_s)
      end
    end

    it "behandelt Backslashes im Namen als Escape-Zeichen (wie das frühere Glob)" do
      track = Track.new(name: "RSpec Sittin\\' And Cryin\\'")
      file_name = "RSpec Artist - RSpec Sittin' And Cryin'.m4a"

      with_download_file(file_name) do
        expect(track.track_path).to eq(downloads_dir.join(file_name).to_s)
      end
    end

    it "ignoriert Dotfiles (wie das frühere Glob)" do
      track = Track.new(name: "RSpec Song Dot")

      with_download_file(".RSpec Artist - RSpec Song Dot.m4a") do
        expect(track.track_path).to be_nil
      end
    end

    it "verlangt vor dem Tracknamen ein beliebiges Zeichen und davor einen Bindestrich" do
      track = Track.new(name: "RSpec Song Prefix")

      with_download_file("RSpec Song Prefix.m4a") do
        expect(track.track_path).to be_nil
      end
    end

    it "gibt nil zurück, wenn keine Datei gefunden wird" do
      track = Track.new(name: "RSpec Unbekannter Song")

      expect(track.track_path).to be_nil
    end

    it "memoisiert das Resultat innerhalb der Instanz" do
      track = Track.new(name: "RSpec Song Memo")
      track.track_path

      with_download_file("RSpec Artist - RSpec Song Memo.m4a") do
        expect(track.track_path).to be_nil
      end
    end

    it "verwendet keinen Dir.chdir (Thread-Sicherheit bei gleichzeitigen Requests)" do
      track = Track.new(name: "RSpec Song")
      expect(Dir).not_to receive(:chdir)

      track.track_path
    end
  end

  describe "#genre" do
    def create_persisted_track(name:, genre: nil)
      album = Album.create!(name: "RSpec Album", spotify_id: "rspec-alb-genre")
      Track.create!(name: name, spotify_id: "rspec-trk-#{name.parameterize}", album: album,
                    duration_ms: 200_000, genre: genre)
    end

    it "gibt nil zurück, wenn kein Track-File gefunden wird" do
      track = Track.new(name: "RSpec Unbekannter Song")

      expect(track.genre).to be_nil
    end

    it "speichert das Genre beim ersten Lesen in der DB" do
      track = create_persisted_track(name: "RSpec Song Cache")
      file_name = "RSpec Artist - RSpec Song Cache.m4a"
      tag = instance_double(WahWah::Mp4Tag, genre: "Fusion")

      with_download_file(file_name) do
        allow(WahWah).to receive(:open).and_return(tag)

        expect(track.genre).to eq("Fusion")
      end

      expect(track.reload[:genre]).to eq("Fusion")
    end

    it "öffnet die Datei nicht mehr, wenn das Genre bereits in der DB liegt" do
      track = create_persisted_track(name: "RSpec Song Cached", genre: "Blues")
      expect(WahWah).to_not receive(:open)

      expect(track.genre).to eq("Blues")
    end

    it "speichert nichts, wenn die Datei kein Genre-Tag hat" do
      track = create_persisted_track(name: "RSpec Song Ohne Tag")
      file_name = "RSpec Artist - RSpec Song Ohne Tag.m4a"
      tag = instance_double(WahWah::Mp4Tag, genre: nil)

      with_download_file(file_name) do
        allow(WahWah).to receive(:open).and_return(tag)

        expect(track.genre).to be_nil
      end

      expect(track.reload[:genre]).to be_nil
    end

    it "liefert das Genre auch für nicht persistierte Tracks, ohne zu speichern" do
      track = Track.new(name: "RSpec Song Neu")
      file_name = "RSpec Artist - RSpec Song Neu.m4a"
      tag = instance_double(WahWah::Mp4Tag, genre: "Fusion")

      with_download_file(file_name) do
        allow(WahWah).to receive(:open).and_return(tag)

        expect(track.genre).to eq("Fusion")
      end
    end

    it "öffnet die gefundene Datei mit WahWah und gibt das Genre zurück" do
      track = Track.new(name: "RSpec Song Genre")
      file_name = "RSpec Artist - RSpec Song Genre.m4a"
      tag = instance_double(WahWah::Mp4Tag, genre: "Fusion")

      with_download_file(file_name) do
        allow(WahWah).to receive(:open).with(downloads_dir.join(file_name).to_s).and_return(tag)

        expect(track.genre).to eq("Fusion")
      end
    end
  end
end
