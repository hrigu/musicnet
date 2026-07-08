# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "reset_unresolved_collided_tracks rake task" do
  let(:downloads_dir) { Rails.root.join("downloads/tracks") }

  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  before do
    Rake::Task["reset_unresolved_collided_tracks"].reenable
  end

  def create_downloaded_file(file_name)
    FileUtils.mkdir_p(downloads_dir)
    FileUtils.touch(downloads_dir.join(file_name))
  end

  after do
    Dir.glob(downloads_dir.join("*RSpec Reset *.m4a")).each { |f| FileUtils.rm_f(f) }
  end

  it "setzt file_name/genre/audio_features zurück, wenn kein Kandidat den Artist-Namen enthält" do
    album = Album.create!(name: "RSpec Album", spotify_id: "rspec-reset-album-1")
    artist_a = Artist.create!(name: "RSpec Reset Unrelated A", spotify_id: "rspec-reset-artist-a")
    artist_b = Artist.create!(name: "RSpec Reset Unrelated B", spotify_id: "rspec-reset-artist-b")

    file_first = "AAA Artist - RSpec Reset Song.m4a"
    file_second = "ZZZ Artist - RSpec Reset Song.m4a"
    create_downloaded_file(file_first)
    create_downloaded_file(file_second)

    unresolved_track = Track.create!(name: "RSpec Reset Song", spotify_id: "rspec-reset-trk-a",
                                     album: album, artists: [artist_a], duration_ms: 200_000,
                                     file_name: file_first, genre: "RSpec Falsches Genre",
                                     audio_features: { "tempo" => 1.0, "energy" => 1.0 })
    Track.create!(name: "RSpec Reset Song", spotify_id: "rspec-reset-trk-b", album: album,
                  artists: [artist_b], duration_ms: 200_000, file_name: file_first)

    Rake::Task["reset_unresolved_collided_tracks"].invoke

    aggregate_failures do
      expect(unresolved_track.reload.file_name).to be_nil
      expect(unresolved_track.genre).to be_nil
      expect(unresolved_track.audio_features).to be_nil
    end
  end

  it "lässt eindeutig auflösbare Tracks unangetastet" do
    album = Album.create!(name: "RSpec Album", spotify_id: "rspec-reset-album-2")
    artist_c = Artist.create!(name: "RSpec Reset Artist C", spotify_id: "rspec-reset-artist-c")
    artist_d = Artist.create!(name: "RSpec Reset Artist D", spotify_id: "rspec-reset-artist-d")

    file_c = "RSpec Reset Artist C - RSpec Reset Eindeutig.m4a"
    file_d = "RSpec Reset Artist D - RSpec Reset Eindeutig.m4a"
    create_downloaded_file(file_c)
    create_downloaded_file(file_d)

    track_c = Track.create!(name: "RSpec Reset Eindeutig", spotify_id: "rspec-reset-trk-c",
                            album: album, artists: [artist_c], duration_ms: 200_000,
                            file_name: file_c, genre: "RSpec Bestehendes Genre")
    track_d = Track.create!(name: "RSpec Reset Eindeutig", spotify_id: "rspec-reset-trk-d",
                            album: album, artists: [artist_d], duration_ms: 200_000, file_name: file_d)

    Rake::Task["reset_unresolved_collided_tracks"].invoke

    aggregate_failures do
      expect(track_c.reload.file_name).to eq(file_c)
      expect(track_c.genre).to eq("RSpec Bestehendes Genre")
      expect(track_d.reload.file_name).to eq(file_d)
    end
  end
end
