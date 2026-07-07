# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "backfill_track_file_names rake task" do
  let(:downloads_dir) { Rails.root.join("downloads/tracks") }

  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  before do
    Rake::Task["backfill_track_file_names"].reenable
  end

  def create_downloaded_file(file_name)
    FileUtils.mkdir_p(downloads_dir)
    FileUtils.touch(downloads_dir.join(file_name))
  end

  after do
    Dir.glob(downloads_dir.join("RSpec Backfill *.m4a")).each { |f| FileUtils.rm_f(f) }
  end

  it "setzt file_name fuer bereits heruntergeladene Tracks ohne file_name" do
    track = Track.create!(spotify_id: "trk-backfill-1", name: "RSpec Backfill Song",
                          album: Album.create!(spotify_id: "alb-backfill-1", name: "Album"), duration_ms: 200_000)
    file_name = "RSpec Backfill Artist - RSpec Backfill Song.m4a"
    create_downloaded_file(file_name)

    Rake::Task["backfill_track_file_names"].invoke

    expect(track.reload.file_name).to eq(file_name)
  end

  it "laesst file_name leer, wenn keine passende Datei existiert" do
    track = Track.create!(spotify_id: "trk-backfill-2", name: "RSpec Backfill Ohne Datei",
                          album: Album.create!(spotify_id: "alb-backfill-2", name: "Album"), duration_ms: 200_000)

    Rake::Task["backfill_track_file_names"].invoke

    expect(track.reload.file_name).to be_nil
  end

  it "laesst bereits gesetzte file_name unangetastet" do
    track = Track.create!(spotify_id: "trk-backfill-3", name: "RSpec Backfill Bereits Gesetzt",
                          album: Album.create!(spotify_id: "alb-backfill-3", name: "Album"), duration_ms: 200_000,
                          file_name: "schon-gesetzt.m4a")

    Rake::Task["backfill_track_file_names"].invoke

    expect(track.reload.file_name).to eq("schon-gesetzt.m4a")
  end
end
