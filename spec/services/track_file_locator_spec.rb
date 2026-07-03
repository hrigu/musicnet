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
