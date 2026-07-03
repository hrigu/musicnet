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
    it "parst audio_features in ein OpenStruct" do
      track = Track.new(audio_features: { energy: 0.7, tempo: 120.5 }.to_json)

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
