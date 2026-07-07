# frozen_string_literal: true

require "rails_helper"

RSpec.describe DownloadResultParser do
  let(:downloads_dir) { Rails.root.join(DownloadPlaylistService::TRACKS_DIR) }
  let(:save_file_path) { "rspec_result_parser.spotdl" }
  let(:errors_file_path) { "rspec_result_parser-errors.txt" }

  # spotdl sync schreibt {"songs": [...]}, spotdl download dagegen ein flaches Array -
  # beide Formen kommen in der Praxis vor (siehe Intent 38, Kleinbatch nutzt "download").
  def write_save_file(songs)
    FileUtils.mkdir_p(downloads_dir)
    File.write(downloads_dir.join(save_file_path), { songs: songs }.to_json)
  end

  def write_save_file_as_array(songs)
    FileUtils.mkdir_p(downloads_dir)
    File.write(downloads_dir.join(save_file_path), songs.to_json)
  end

  def write_errors_file(content)
    FileUtils.mkdir_p(downloads_dir)
    File.write(downloads_dir.join(errors_file_path), content)
  end

  # Erfolg wird ueber die tatsaechliche Datei entschieden, nicht ueber download_url (siehe
  # unten "Duplicate-Skip") - dafuer muss eine passende Datei im Downloads-Ordner liegen,
  # gleiches Namensschema wie in den anderen Specs (TrackFileLocator).
  def create_downloaded_file(track)
    FileUtils.mkdir_p(downloads_dir)
    FileUtils.touch(downloads_dir.join("RSpec Artist - #{track.name}.m4a"))
  end

  after do
    FileUtils.rm_f(downloads_dir.join(save_file_path))
    FileUtils.rm_f(downloads_dir.join(errors_file_path))
    Dir.glob(downloads_dir.join("RSpec Artist - *.m4a")).each { |f| FileUtils.rm_f(f) }
  end

  describe "#downloaded" do
    it "liefert Name und Provider fuer Tracks mit Datei und gesetzter download_url" do
      track = Track.create!(spotify_id: "trk-drp-1", name: "Minor Swing",
                            album: Album.create!(spotify_id: "alb-drp-1", name: "Album"), duration_ms: 200_000)
      create_downloaded_file(track)
      write_save_file([{ "song_id" => track.spotify_id, "download_url" => "https://www.youtube.com/watch?v=xyz" }])

      result = described_class.new([track], save_file_path: save_file_path, errors_file_path: errors_file_path).parse

      expect(result.downloaded).to eq([{ name: "Minor Swing", provider: "YouTube" }])
      expect(result.failed).to eq([])
    end

    it "liest auch die flache Array-Form, die spotdl download (statt sync) schreibt" do
      track = Track.create!(spotify_id: "trk-drp-1b", name: "Minor Swing",
                            album: Album.create!(spotify_id: "alb-drp-1b", name: "Album"), duration_ms: 200_000)
      create_downloaded_file(track)
      write_save_file_as_array(
        [{ "song_id" => track.spotify_id, "download_url" => "https://www.youtube.com/watch?v=xyz" }]
      )

      result = described_class.new([track], save_file_path: save_file_path, errors_file_path: errors_file_path).parse

      expect(result.downloaded).to eq([{ name: "Minor Swing", provider: "YouTube" }])
    end

    it "erkennt Bandcamp als Provider" do
      track = Track.create!(spotify_id: "trk-drp-2", name: "Some Song",
                            album: Album.create!(spotify_id: "alb-drp-2", name: "Album"), duration_ms: 200_000)
      create_downloaded_file(track)
      write_save_file([{ "song_id" => track.spotify_id, "download_url" => "https://artist.bandcamp.com/track/x" }])

      result = described_class.new([track], save_file_path: save_file_path, errors_file_path: errors_file_path).parse

      expect(result.downloaded).to eq([{ name: "Some Song", provider: "Bandcamp" }])
    end

    it "zaehlt eine Datei als Erfolg, auch wenn spotdl download_url nicht gesetzt hat " \
       "(Duplicate-Skip: Datei existierte schon, spotdl unterscheidet das nicht von einem echten Fehlschlag)" do
      track = Track.create!(spotify_id: "trk-drp-10", name: "Lost In The Lows",
                            album: Album.create!(spotify_id: "alb-drp-10", name: "Album"), duration_ms: 200_000)
      create_downloaded_file(track)
      write_save_file([{ "song_id" => track.spotify_id, "download_url" => nil }])

      result = described_class.new([track], save_file_path: save_file_path, errors_file_path: errors_file_path).parse

      expect(result.downloaded).to eq([{ name: "Lost In The Lows", provider: "unbekannt" }])
      expect(result.failed).to eq([])
    end
  end

  describe "file_name persistieren" do
    it "speichert den tatsaechlichen Dateinamen fuer erfolgreich heruntergeladene Tracks" do
      track = Track.create!(spotify_id: "trk-drp-11", name: "Some New Song",
                            album: Album.create!(spotify_id: "alb-drp-11", name: "Album"), duration_ms: 200_000)
      create_downloaded_file(track)
      write_save_file([{ "song_id" => track.spotify_id, "download_url" => "https://www.youtube.com/watch?v=xyz" }])

      described_class.new([track], save_file_path: save_file_path, errors_file_path: errors_file_path).parse

      expect(track.reload.file_name).to eq("RSpec Artist - Some New Song.m4a")
    end

    it "laesst file_name leer fuer fehlgeschlagene Tracks" do
      track = Track.create!(spotify_id: "trk-drp-12", name: "Missing Song",
                            album: Album.create!(spotify_id: "alb-drp-12", name: "Album"), duration_ms: 200_000)
      write_save_file([{ "song_id" => track.spotify_id, "download_url" => nil }])

      described_class.new([track], save_file_path: save_file_path, errors_file_path: errors_file_path).parse

      expect(track.reload.file_name).to be_nil
    end
  end

  describe "lange Fehlermeldungen" do
    it "kuerzt den Grund, damit er nicht unbegrenzt lang werden kann (landet im Session-Flash)" do
      track = Track.create!(spotify_id: "trk-drp-9", name: "Minor Swing",
                            album: Album.create!(spotify_id: "alb-drp-9", name: "Album"), duration_ms: 200_000)
      write_save_file([{ "song_id" => track.spotify_id, "download_url" => nil }])
      write_errors_file("#{'x' * 300} Minor Swing\n")

      result = described_class.new([track], save_file_path: save_file_path, errors_file_path: errors_file_path).parse

      expect(result.failed.first[:reason].length).to be <= 150
    end
  end

  describe "#failed" do
    it "liefert den Grund aus der Errors-Datei, wenn keine Datei existiert und eine passende Zeile existiert" do
      track = Track.create!(spotify_id: "trk-drp-3", name: "Minor Swing",
                            album: Album.create!(spotify_id: "alb-drp-3", name: "Album"), duration_ms: 200_000)
      write_save_file([{ "song_id" => track.spotify_id, "download_url" => nil }])
      write_errors_file("LookupError: No results found for song: Django Reinhardt - Minor Swing\n")

      result = described_class.new([track], save_file_path: save_file_path, errors_file_path: errors_file_path).parse

      expect(result.failed).to eq(
        [{ name: "Minor Swing", reason: "LookupError: No results found for song: Django Reinhardt - Minor Swing" }]
      )
    end

    it "liefert einen generischen Grund, wenn keine Errors-Datei existiert oder keine Zeile passt" do
      track = Track.create!(spotify_id: "trk-drp-4", name: "Minor Swing",
                            album: Album.create!(spotify_id: "alb-drp-4", name: "Album"), duration_ms: 200_000)
      write_save_file([{ "song_id" => track.spotify_id, "download_url" => nil }])

      result = described_class.new([track], save_file_path: save_file_path, errors_file_path: errors_file_path).parse

      expect(result.failed).to eq([{ name: "Minor Swing", reason: "Kein Treffer gefunden" }])
    end

    it "behandelt Tracks, die gar nicht in der Save-Datei auftauchen, ebenfalls als fehlgeschlagen" do
      track = Track.create!(spotify_id: "trk-drp-5", name: "Ghost Track",
                            album: Album.create!(spotify_id: "alb-drp-5", name: "Album"), duration_ms: 200_000)
      write_save_file([])

      result = described_class.new([track], save_file_path: save_file_path, errors_file_path: errors_file_path).parse

      expect(result.failed).to eq([{ name: "Ghost Track", reason: "Kein Treffer gefunden" }])
    end
  end

  describe "Aufraeumen" do
    it "loescht die Errors-Datei immer nach dem Parsen" do
      track = Track.create!(spotify_id: "trk-drp-6", name: "Track",
                            album: Album.create!(spotify_id: "alb-drp-6", name: "Album"), duration_ms: 200_000)
      write_save_file([{ "song_id" => track.spotify_id, "download_url" => nil }])
      write_errors_file("irgendein Fehler\n")

      described_class.new([track], save_file_path: save_file_path, errors_file_path: errors_file_path).parse

      expect(File).to_not exist(downloads_dir.join(errors_file_path))
    end

    it "loescht die Save-Datei nur, wenn cleanup_save_file: true uebergeben wird" do
      track = Track.create!(spotify_id: "trk-drp-7", name: "Track",
                            album: Album.create!(spotify_id: "alb-drp-7", name: "Album"), duration_ms: 200_000)
      write_save_file([{ "song_id" => track.spotify_id, "download_url" => nil }])

      parser = described_class.new([track], save_file_path: save_file_path, errors_file_path: errors_file_path,
                                            cleanup_save_file: true)
      parser.parse

      expect(File).to_not exist(downloads_dir.join(save_file_path))
    end

    it "behaelt die Save-Datei, wenn cleanup_save_file nicht gesetzt ist" do
      track = Track.create!(spotify_id: "trk-drp-8", name: "Track",
                            album: Album.create!(spotify_id: "alb-drp-8", name: "Album"), duration_ms: 200_000)
      write_save_file([{ "song_id" => track.spotify_id, "download_url" => nil }])

      described_class.new([track], save_file_path: save_file_path, errors_file_path: errors_file_path).parse

      expect(File).to exist(downloads_dir.join(save_file_path))
    end
  end
end
