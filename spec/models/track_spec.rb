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
