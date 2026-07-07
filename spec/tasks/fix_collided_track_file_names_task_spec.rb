# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "fix_collided_track_file_names rake task" do
  let(:downloads_dir) { Rails.root.join("downloads/tracks") }

  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  before do
    Rake::Task["fix_collided_track_file_names"].reenable
  end

  def create_downloaded_file(file_name)
    FileUtils.mkdir_p(downloads_dir)
    FileUtils.touch(downloads_dir.join(file_name))
  end

  after do
    Dir.glob(downloads_dir.join("RSpec Fix *.m4a")).each { |f| FileUtils.rm_f(f) }
    Dir.glob(downloads_dir.join("*RSpec Ambiguous Fix Song.m4a")).each { |f| FileUtils.rm_f(f) }
  end

  it "korrigiert file_name für einen eindeutig auflösbaren Kollisionsfall und setzt " \
     "genre/audio_features zurück" do
    album = Album.create!(name: "RSpec Album", spotify_id: "rspec-fix-album-1")
    artist_a = Artist.create!(name: "RSpec Fix Artist A", spotify_id: "rspec-fix-artist-a")
    artist_b = Artist.create!(name: "RSpec Fix Artist B", spotify_id: "rspec-fix-artist-b")

    file_a = "RSpec Fix Artist A - RSpec Fix Song.m4a"
    file_b = "RSpec Fix Artist B - RSpec Fix Song.m4a"
    create_downloaded_file(file_a)
    create_downloaded_file(file_b)

    track_a = Track.create!(name: "RSpec Fix Song", spotify_id: "rspec-fix-trk-a", album: album,
                            artists: [artist_a], duration_ms: 200_000, file_name: file_a)
    track_b = Track.create!(name: "RSpec Fix Song", spotify_id: "rspec-fix-trk-b", album: album,
                            artists: [artist_b], duration_ms: 200_000, file_name: file_a,
                            genre: "RSpec Falsches Genre",
                            audio_features: { "tempo" => 1.0, "energy" => 1.0 })

    status = instance_double(Process::Status, success?: true)
    output = { rhythm: { bpm: 120.0 }, lowlevel: { average_loudness: 0.3 } }.to_json
    allow(Open3).to receive(:capture3).and_return([output, "", status])

    Rake::Task["fix_collided_track_file_names"].invoke

    aggregate_failures do
      expect(track_a.reload.file_name).to eq(file_a)
      expect(track_b.reload.file_name).to eq(file_b)
      expect(track_b.genre).to be_nil
      expect(track_b.reload.audio_features).to eq("tempo" => 120.0, "energy" => 0.3)
    end
  end

  it "lässt einen nicht eindeutig auflösbaren Kollisionsfall sowie bereits korrekte " \
     "file_name-Werte unangetastet" do
    album = Album.create!(name: "RSpec Album", spotify_id: "rspec-fix-album-2")
    artist_c = Artist.create!(name: "RSpec Unrelated C", spotify_id: "rspec-fix-artist-c")
    artist_d = Artist.create!(name: "RSpec Unrelated D", spotify_id: "rspec-fix-artist-d")

    file_first = "AAA Artist - RSpec Ambiguous Fix Song.m4a"
    file_second = "ZZZ Artist - RSpec Ambiguous Fix Song.m4a"
    create_downloaded_file(file_first)
    create_downloaded_file(file_second)

    ambiguous_track = Track.create!(name: "RSpec Ambiguous Fix Song", spotify_id: "rspec-fix-trk-c",
                                    album: album, artists: [artist_c], duration_ms: 200_000,
                                    file_name: file_first, genre: "RSpec Bestehendes Genre")
    Track.create!(name: "RSpec Ambiguous Fix Song", spotify_id: "rspec-fix-trk-d", album: album,
                 artists: [artist_d], duration_ms: 200_000, file_name: file_first)

    Rake::Task["fix_collided_track_file_names"].invoke

    aggregate_failures do
      expect(ambiguous_track.reload.file_name).to eq(file_first)
      expect(ambiguous_track.genre).to eq("RSpec Bestehendes Genre")
    end
  end
end
