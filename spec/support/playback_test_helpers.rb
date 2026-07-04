# frozen_string_literal: true

# Gemeinsame Helfer fuer System-Specs rund um den globalen Audio-Player (Intent 40/41).
module PlaybackTestHelpers
  def downloads_dir
    Rails.root.join("downloads/tracks")
  end

  def create_playable_track(name, spotify_id:, artist_name: nil, playlist_name: nil)
    album = Album.find_or_create_by!(spotify_id: "alb-playback-helpers") { |a| a.name = "Playback-Test-Album" }
    track = Track.create!(name: name, spotify_id: spotify_id, album: album, duration_ms: 200_000)
    track.artists << Artist.create!(name: artist_name, spotify_id: "art-#{spotify_id}") if artist_name
    if playlist_name
      playlist = Playlist.create!(name: playlist_name, spotify_id: "pl-#{spotify_id}")
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
    end
    FileUtils.mkdir_p(downloads_dir)
    FileUtils.touch(downloads_dir.join("RSpec Artist - #{name}.m4a"))
    track
  end

  # Wie create_playable_track, aber mit einer echten, abspielbaren (stummen) Audiodatei statt
  # einer leeren - noetig fuer Specs, die echtes Laden/Seeken im Browser pruefen (ein <audio>
  # kann bei einer leeren Datei weder Dauer noch Position ermitteln).
  def create_track_with_real_audio(name, spotify_id:)
    track = create_playable_track(name, spotify_id: spotify_id)
    FileUtils.cp(Rails.root.join("spec/fixtures/files/silence.m4a"), downloads_dir.join("RSpec Artist - #{name}.m4a"))
    track
  end

  def play_button_for(track_name)
    page.find("tr", text: track_name).find_button("Abspielen")
  end

  def enqueue_button_for(track_name)
    page.find("tr", text: track_name).find_button("Zur Queue hinzufügen")
  end

  def player_toggle_button
    page.find("#global-audio-player").find_button("Play/Pause")
  end
end

RSpec.configure do |config|
  config.include PlaybackTestHelpers, type: :system

  config.after(:each, type: :system) do
    Dir.glob(Rails.root.join("downloads/tracks/RSpec Artist - *.m4a")).each { |f| FileUtils.rm_f(f) }
  end
end
