# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Artists", type: :request do
  fixtures :users

  before do
    sign_in users(:one)
    allow_any_instance_of(Track).to receive(:track_path).and_return(nil)
  end

  def create_artist_with_track
    album = Album.create!(name: "Album", spotify_id: "alb1")
    artist = Artist.create!(name: "Artist", spotify_id: "art1")
    Track.create!(name: "Track", spotify_id: "trk1", album: album, artists: [artist], duration_ms: 200_000)
    artist
  end

  describe "GET /artists" do
    it "liefert Erfolg" do
      create_artist_with_track

      get artists_path

      expect(response).to have_http_status(:success)
    end

    it "zeigt die Playlist-Badges ohne eine Query pro Künstler" do
      album = Album.create!(name: "Album", spotify_id: "alb-q1")
      playlist = Playlist.create!(spotify_id: "pl-q1", name: "Fusion Badge")
      2.times do |i|
        artist = Artist.create!(name: "Artist #{i}", spotify_id: "art-q#{i}")
        track = Track.create!(name: "Track #{i}", spotify_id: "trk-q#{i}", album: album,
                              artists: [artist], duration_ms: 200_000)
        PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
      end

      queries = []
      callback = lambda do |_name, _start, _finish, _id, payload|
        queries << payload[:sql] unless payload[:name] == "SCHEMA"
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get artists_path
      end

      expect(response).to have_http_status(:success)
      aggregate_failures do
        expect(queries.count { |sql| sql.include?('FROM "playlists"') }).to eq(1)
        expect(response.body.scan("F_Badge").length).to eq(2)
      end
    end
  end

  describe "GET /artists/:id" do
    it "liefert Erfolg" do
      artist = create_artist_with_track

      get artist_path(artist)

      expect(response).to have_http_status(:success)
    end

    it "lädt Tracks und Alben gebündelt (je Tabelle eine Query, ein Verzeichnis-Scan)" do
      album = Album.create!(name: "Album", spotify_id: "alb-s1")
      artist = Artist.create!(name: "Artist Show", spotify_id: "art-s1")
      playlist = Playlist.create!(spotify_id: "pl-s1", name: "Fusion Show")
      2.times do |i|
        track = Track.create!(name: "RSpec Show #{i}", spotify_id: "trk-s#{i}", album: album,
                              artists: [artist], duration_ms: 200_000)
        PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
      end
      allow_any_instance_of(Track).to receive(:track_path).and_call_original
      allow(Dir).to receive(:children).and_call_original

      queries = []
      callback = lambda do |_name, _start, _finish, _id, payload|
        queries << payload[:sql] unless payload[:name] == "SCHEMA"
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get artist_path(artist)
      end

      expect(response).to have_http_status(:success)
      aggregate_failures do
        expect(queries.count { |sql| sql.include?('FROM "playlists"') }).to eq(1)
        expect(queries.count { |sql| sql.include?('FROM "playlist_tracks"') }).to eq(1)
        # Track-Tabelle der Seite + Tracks-Spalte der Alben-Tabelle
        expect(queries.count { |sql| sql.include?('FROM "tracks"') }).to eq(2)
        # belongs_to-Preload der Track-Tabelle + Alben-Tabelle selbst
        expect(queries.count { |sql| sql.include?('FROM "albums"') }).to eq(2)
        # Artist.find + Künstler-Preload der Track-Tabelle + der Alben-Tabelle
        expect(queries.count { |sql| sql.include?('FROM "artists"') }).to eq(3)
        expect(Dir).to have_received(:children).with(TrackFileLocator.downloads_dir).at_most(:once)
      end
    end
  end
end
