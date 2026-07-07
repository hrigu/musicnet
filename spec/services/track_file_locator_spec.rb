# frozen_string_literal: true

require "rails_helper"

RSpec.describe TrackFileLocator do
  let(:downloads_dir) { Rails.root.join("downloads/tracks") }

  def with_download_file(file_name)
    FileUtils.mkdir_p(downloads_dir)
    FileUtils.touch(downloads_dir.join(file_name))
    yield
  ensure
    FileUtils.rm_f(downloads_dir.join(file_name))
  end

  describe ".resolve_track_path" do
    it "findet die passende, sanitisierte Datei im downloads/tracks-Verzeichnis" do
      track = Track.new(name: "RSpec Song: Live?")
      file_name = "RSpec Artist - RSpec Song- Live.m4a"

      with_download_file(file_name) do
        expect(described_class.resolve_track_path(track)).to eq(downloads_dir.join(file_name).to_s)
      end
    end

    it "nutzt eine gesetzte file_name direkt, ohne Namens-Matching gegen den Track-Namen" do
      file_name = "RSpec Artist - Komplett anderer Dateiname.m4a"
      track = Track.new(name: "RSpec Song ohne jede Übereinstimmung", file_name: file_name)

      with_download_file(file_name) do
        expect(described_class.resolve_track_path(track)).to eq(downloads_dir.join(file_name).to_s)
      end
    end

    it "faellt aufs Namens-Matching zurueck, wenn die per file_name referenzierte Datei fehlt" do
      fallback_file_name = "RSpec Artist - RSpec Song- Live.m4a"
      track = Track.new(name: "RSpec Song: Live", file_name: "nicht-mehr-vorhanden.m4a")

      with_download_file(fallback_file_name) do
        expect(described_class.resolve_track_path(track)).to eq(downloads_dir.join(fallback_file_name).to_s)
      end
    end

    it "waehlt bei mehreren passenden Dateien diejenige, die einen Artist-Namen des Tracks enthaelt" do
      album = Album.create!(name: "RSpec Album", spotify_id: "rspec-album-artist-match")
      artist = Artist.create!(name: "RSpec Artist B", spotify_id: "rspec-artist-b")
      track = Track.create!(name: "RSpec Ambiguous Song", spotify_id: "rspec-trk-ambiguous-1",
                            album: album, artists: [artist], duration_ms: 200_000)
      file_a = "RSpec Artist A - RSpec Ambiguous Song.m4a"
      file_b = "RSpec Artist B - RSpec Ambiguous Song.m4a"

      with_download_file(file_a) do
        with_download_file(file_b) do
          expect(described_class.resolve_track_path(track)).to eq(downloads_dir.join(file_b).to_s)
        end
      end
    end

    it "normalisiert Anfuehrungszeichen im Artist-Namen genauso wie beim Songnamen (Intent 74 Nachtrag)" do
      album = Album.create!(name: "RSpec Album", spotify_id: "rspec-album-quote-artist")
      artist = Artist.create!(name: 'RSpec Jimmy "Duck" Holmes', spotify_id: "rspec-artist-quote")
      track = Track.create!(name: "RSpec Quote Song", spotify_id: "rspec-trk-quote-artist",
                            album: album, artists: [artist], duration_ms: 200_000)
      file_wrong = "AAA Other Artist - RSpec Quote Song.m4a"
      file_correct = "RSpec Jimmy 'Duck' Holmes - RSpec Quote Song.m4a"

      with_download_file(file_wrong) do
        with_download_file(file_correct) do
          expect(described_class.resolve_track_path(track)).to eq(downloads_dir.join(file_correct).to_s)
        end
      end
    end

    it "faellt bei mehreren passenden Dateien ohne Artist-Treffer auf den ersten sortierten Treffer zurueck" do
      album = Album.create!(name: "RSpec Album", spotify_id: "rspec-album-no-match")
      artist = Artist.create!(name: "RSpec Unbeteiligter Artist", spotify_id: "rspec-artist-unrelated")
      track = Track.create!(name: "RSpec Ambiguous Song Zwei", spotify_id: "rspec-trk-ambiguous-2",
                            album: album, artists: [artist], duration_ms: 200_000)
      file_a = "AAA Artist - RSpec Ambiguous Song Zwei.m4a"
      file_b = "ZZZ Artist - RSpec Ambiguous Song Zwei.m4a"

      with_download_file(file_a) do
        with_download_file(file_b) do
          expect(described_class.resolve_track_path(track)).to eq(downloads_dir.join(file_a).to_s)
        end
      end
    end
  end

  describe ".preload_track_paths" do
    it "setzt track_path für alle Tracks mit einem einzigen Verzeichnis-Scan" do
      found = Track.new(name: "RSpec Song: Live")
      missing = Track.new(name: "RSpec Nicht Vorhanden")
      file_name = "RSpec Artist - RSpec Song- Live.m4a"

      with_download_file(file_name) do
        described_class.preload_track_paths([found, missing])
      end

      aggregate_failures do
        expect(found.track_path).to eq(downloads_dir.join(file_name).to_s)
        expect(missing.track_path).to be_nil
      end
    end
  end
end
