# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Artists", type: :request do
  fixtures :users

  before do
    sign_in users(:one)
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

    it "zeigt nur Artists der aktiven Bibliothek, wenn eine gesetzt ist (Intent 57)" do
      blues = Library.create!(name: "Blues", keyword: "blues")
      users(:one).update!(active_library: blues)
      album = Album.create!(name: "Album", spotify_id: "alb-cat")
      blues_artist = Artist.create!(name: "RSpec Blues Artist Idx", spotify_id: "art-cat-idx-blues")
      fusion_artist = Artist.create!(name: "RSpec Fusion Artist Idx", spotify_id: "art-cat-idx-fusion")
      blues_track = Track.create!(name: "A", spotify_id: "trk-cat-idx-blues", album: album,
                                  artists: [blues_artist], duration_ms: 200_000)
      fusion_track = Track.create!(name: "B", spotify_id: "trk-cat-idx-fusion", album: album,
                                   artists: [fusion_artist], duration_ms: 200_000)
      blues_playlist = Playlist.create!(name: "RSpec Blues Session Idx", spotify_id: "pl-cat-idx-art-blues")
      fusion_playlist = Playlist.create!(name: "RSpec Fusion Abende Idx", spotify_id: "pl-cat-idx-art-fusion")
      blues_playlist.libraries << blues
      PlaylistTrack.create!(playlist: blues_playlist, track: blues_track, added_at: Time.current)
      PlaylistTrack.create!(playlist: fusion_playlist, track: fusion_track, added_at: Time.current)

      get artists_path

      names = Nokogiri::HTML(response.body).css("tbody tr th a").map(&:text)
      expect(names).to include("RSpec Blues Artist Idx")
      expect(names).to_not include("RSpec Fusion Artist Idx")
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

    it "verlinkt Sortier-Header auf die Artist-Seite selbst statt auf /tracks (Intent 63)" do
      artist = create_artist_with_track

      get artist_path(artist)

      link = Nokogiri::HTML(response.body).css("thead th a").find { |a| a.text.start_with?("Dauer") }
      expect(link[:href]).to eq(artist_path(artist, sort: "duration_ms", direction: "asc"))
    end

    it "sortiert die Tracks-Tabelle nach der gewählten Spalte und Richtung (Intent 63)" do
      album = Album.create!(name: "Album", spotify_id: "alb-s2")
      artist = Artist.create!(name: "Artist Sort", spotify_id: "art-s2")
      # In Erstellungsreihenfolge (B vor A) angelegt, damit ein Test, der ohne echte Sortierung
      # zufaellig durch die natuerliche DB-Reihenfolge "besteht", hier tatsaechlich rot wird.
      Track.create!(name: "B Track", spotify_id: "trk-s2-b", album: album, artists: [artist], duration_ms: 200_000)
      Track.create!(name: "A Track", spotify_id: "trk-s2-a", album: album, artists: [artist], duration_ms: 100_000)

      get artist_path(artist, sort: "name", direction: "asc")

      names = Nokogiri::HTML(response.body).css("tbody tr th a").map(&:text)
      expect(names).to eq(["A Track", "B Track"])
    end

    it "zeigt 'Alben' als Ueberschrift statt als Tabellen-Caption (Intent 65)" do
      artist = create_artist_with_track

      get artist_path(artist)

      html = Nokogiri::HTML(response.body)
      aggregate_failures do
        expect(html.css("h2").map(&:text)).to include("Alben")
        expect(html.css("caption")).to be_empty
      end
    end

    it "sortiert die Alben absteigend nach Release Date (Intent 65)" do
      artist = Artist.create!(name: "Artist Albums Sort", spotify_id: "art-alb-sort")
      old_album = Album.create!(name: "Altes Album", spotify_id: "alb-sort-old", release_date: Date.new(2000, 1, 1))
      new_album = Album.create!(name: "Neues Album", spotify_id: "alb-sort-new", release_date: Date.new(2020, 1, 1))
      Track.create!(name: "Track Alt", spotify_id: "trk-sort-old", album: old_album, artists: [artist],
                    duration_ms: 200_000)
      Track.create!(name: "Track Neu", spotify_id: "trk-sort-new", album: new_album, artists: [artist],
                    duration_ms: 200_000)

      get artist_path(artist)

      names = Nokogiri::HTML(response.body).css("table.table-tracks-detailed").last.css("tbody tr th").map do |th|
        th.text.squish
      end
      expect(names).to eq(["Neues Album", "Altes Album"])
    end

    it "zeigt die Album-Bekanntheit als Meter statt als nackte Zahl (Intent 65)" do
      artist = Artist.create!(name: "Artist Album Meter", spotify_id: "art-alb-meter")
      album = Album.create!(name: "Album Meter", spotify_id: "alb-meter", popularity: 55)
      Track.create!(name: "Track", spotify_id: "trk-alb-meter", album: album, artists: [artist], duration_ms: 200_000)

      get artist_path(artist)

      html = Nokogiri::HTML(response.body)
      albums_table = html.css("table.table-tracks-detailed").last
      expect(albums_table.at_css(".track-meter .progress-bar")).to be_present
    end

    it "verlinkt Spotify als Symbol in der letzten Spalte mit neuem Tab (Intent 65)" do
      artist = Artist.create!(name: "Artist Album Spotify", spotify_id: "art-alb-spotify")
      album = Album.create!(name: "Album Spotify", spotify_id: "alb-spotify", url: "https://open.spotify.com/album/x")
      Track.create!(name: "Track", spotify_id: "trk-alb-spotify", album: album, artists: [artist],
                    duration_ms: 200_000)

      get artist_path(artist)

      html = Nokogiri::HTML(response.body)
      albums_table = html.css("table.table-tracks-detailed").last
      row = albums_table.at_css("tbody tr")
      cells = row.css("th, td")
      spotify_link = cells.last.at_css("a")
      aggregate_failures do
        expect(spotify_link[:href]).to eq("https://open.spotify.com/album/x")
        expect(spotify_link.text.strip).to eq("↗")
        expect(spotify_link[:target]).to eq("_blank")
        expect(response.body).to_not include("zu Spotify")
      end
    end

    it "zeigt den vollen Album-Namen ohne kuenstliche Kuerzung (Intent 65 Nachtrag)" do
      album = Album.create!(name: "Ein ziemlich langer, aber vollstaendig lesbarer Album-Titel",
                            spotify_id: "alb-fullname")
      artist = Artist.create!(name: "Artist Full Name", spotify_id: "art-fullname")
      Track.create!(name: "Track", spotify_id: "trk-fullname", album: album, artists: [artist], duration_ms: 200_000)

      get artist_path(artist)

      html = Nokogiri::HTML(response.body)
      albums_table = html.css("table.table-tracks-detailed").last
      name_cell = albums_table.at_css("tbody tr th")
      expect(name_cell.text.squish).to eq("Ein ziemlich langer, aber vollstaendig lesbarer Album-Titel")
    end

    it "reserviert der Album-Name-Spalte mehr Tabellenbreite (Intent 65 Nachtrag)" do
      artist = create_artist_with_track

      get artist_path(artist)

      html = Nokogiri::HTML(response.body)
      albums_table = html.css("table.table-tracks-detailed").last
      name_header = albums_table.at_css("thead th")
      expect(name_header[:style]).to match(/width:\s*\d/)
    end

    it "zeigt Tracks und Künstler des Albums als unterscheidbare Chips statt als Fliesstext (Intent 65 Nachtrag)" do
      artist = Artist.create!(name: "Artist Chips", spotify_id: "art-chips")
      album = Album.create!(name: "Album Chips", spotify_id: "alb-chips")
      Track.create!(name: "Track Eins", spotify_id: "trk-chips-1", album: album, artists: [artist],
                    duration_ms: 200_000)
      Track.create!(name: "Track Zwei", spotify_id: "trk-chips-2", album: album, artists: [artist],
                    duration_ms: 200_000)

      get artist_path(artist)

      html = Nokogiri::HTML(response.body)
      albums_table = html.css("table.table-tracks-detailed").last
      row = albums_table.at_css("tbody tr")
      tracks_cell, artists_cell = row.css("td")[2, 2]
      aggregate_failures do
        expect(tracks_cell.css("a.badge").map(&:text)).to eq(["Track Eins", "Track Zwei"])
        expect(artists_cell.css("a.badge").map(&:text)).to eq(["Artist Chips"])
      end
    end
  end
end
