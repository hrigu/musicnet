# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tracks", type: :request do
  fixtures :users

  let(:downloads_dir) { Rails.root.join("downloads/tracks") }

  def create_track(name: "Song", spotify_id: "trk1")
    album = Album.create!(name: "Album", spotify_id: "alb-#{spotify_id}")
    Track.create!(name: name, spotify_id: spotify_id, album: album, duration_ms: 200_000)
  end

  def with_download_file(file_name, content: nil)
    FileUtils.mkdir_p(downloads_dir)
    if content
      File.binwrite(downloads_dir.join(file_name), content)
    else
      FileUtils.touch(downloads_dir.join(file_name))
    end
    yield
  ensure
    FileUtils.rm_f(downloads_dir.join(file_name))
  end

  before do
    sign_in users(:one)
  end

  describe "GET /tracks" do
    it "liefert Erfolg" do
      create_track

      get tracks_path

      expect(response).to have_http_status(:success)
    end

    it "zeigt ein Badge statt des Players für Tracks ohne Soundfile" do
      create_track

      get tracks_path

      aggregate_failures do
        expect(response.body).to include("kein File")
        expect(response.body).to_not include("audio-trigger")
      end
    end

    it "zeigt den Player für Tracks mit Soundfile" do
      create_track

      with_download_file("RSpec Artist - Song.m4a") do
        get tracks_path
      end

      aggregate_failures do
        expect(response.body).to include("audio-trigger")
        expect(response.body).to_not include("kein File")
      end
    end

    it "zeigt die Playlist-Badges ohne eine Query pro Track" do
      playlist = Playlist.create!(spotify_id: "pl-q1", name: "Fusion Badge")
      other_playlist = Playlist.create!(spotify_id: "pl-q2", name: "Blues Badge")
      3.times do |i|
        track = create_track(name: "Track #{i}", spotify_id: "trk-q#{i}")
        PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
        PlaylistTrack.create!(playlist: other_playlist, track: track, added_at: Time.current)
      end

      queries = []
      callback = lambda do |_name, _start, _finish, _id, payload|
        queries << payload[:sql] unless payload[:name] == "SCHEMA"
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get tracks_path
      end

      expect(response).to have_http_status(:success)
      aggregate_failures do
        expect(queries.count { |sql| sql.include?('FROM "playlist_tracks"') }).to eq(1)
        expect(queries.count { |sql| sql.include?('FROM "playlists"') }).to eq(1)
        expect(response.body).to include("F_Badge")
        expect(response.body).to include("B_Badge")
      end
    end
  end

  describe "GET /tracks - Paginierung" do
    before { 51.times { |i| create_track(name: "Pag Track #{i}", spotify_id: "pag-#{i}") } }

    it "zeigt nur eine Seite an Tracks" do
      get tracks_path

      rows = Nokogiri::HTML(response.body).css("tbody tr")
      expect(rows.size).to eq(50)
    end

    it "zeigt die restlichen Tracks auf der zweiten Seite" do
      get tracks_path(page: 2)

      rows = Nokogiri::HTML(response.body).css("tbody tr")
      expect(rows.size).to eq(1)
    end

    it "rendert eine Pagination-Navigation" do
      get tracks_path

      expect(response.body).to include('class="pagination')
    end
  end

  describe "GET /tracks - Sortierung" do
    def header_link_query(response_body, label)
      link = Nokogiri::HTML(response_body).css("thead th a").find { |a| a.text.start_with?(label) }
      Rack::Utils.parse_nested_query(URI.parse(link[:href]).query)
    end

    before do
      create_track(name: "B Track", spotify_id: "srt-b")
      create_track(name: "A Track", spotify_id: "srt-a")
    end

    it "sortiert standardmässig nach Name aufsteigend" do
      get tracks_path

      names = Nokogiri::HTML(response.body).css("tbody tr th a").map(&:text)
      expect(names).to eq(["A Track", "B Track"])
    end

    it "sortiert nach der gewählten Spalte und Richtung" do
      get tracks_path(sort: "name", direction: "desc")

      names = Nokogiri::HTML(response.body).css("tbody tr th a").map(&:text)
      expect(names).to eq(["B Track", "A Track"])
    end

    it "verlinkt den Name-Header standardmässig auf absteigend (Toggle der aktiven Spalte)" do
      get tracks_path

      query = header_link_query(response.body, "Name")
      expect(query).to include("sort" => "name", "direction" => "desc")
    end

    it "verlinkt eine inaktive Spalte auf aufsteigend" do
      get tracks_path(sort: "name", direction: "desc")

      query = header_link_query(response.body, "Dauer")
      expect(query).to include("sort" => "duration_ms", "direction" => "asc")
    end

    it "setzt die Seite in den Sortier-Links zurück" do
      get tracks_path(page: 2)

      query = header_link_query(response.body, "Name")
      expect(query).to_not have_key("page")
    end
  end

  describe "GET /tracks - Suche" do
    before do
      create_track(name: "RSpec Blues Shuffle", spotify_id: "srch-hit")
      create_track(name: "Andere Nummer", spotify_id: "srch-miss")
    end

    it "zeigt nur Tracks, die auf den Suchbegriff passen" do
      get tracks_path(q: "blues shuffle")

      names = Nokogiri::HTML(response.body).css("tbody tr th a").map(&:text)
      expect(names).to eq(["RSpec Blues Shuffle"])
    end

    it "zeigt das Suchfeld mit dem aktuellen Suchbegriff vorausgefüllt" do
      get tracks_path(q: "blues shuffle")

      field = Nokogiri::HTML(response.body).at_css("input[name='q']")
      expect(field[:value]).to eq("blues shuffle")
    end

    it "behält Sortierung beim Suchen bei" do
      get tracks_path(q: "blues shuffle", sort: "popularity", direction: "desc")

      form = Nokogiri::HTML(response.body).at_css("form#tracks-search")
      expect(form.at_css("input[name='sort']")[:value]).to eq("popularity")
      expect(form.at_css("input[name='direction']")[:value]).to eq("desc")
    end

    it "setzt die Seite bei neuer Suche zurück (kein page-Feld im Suchformular)" do
      get tracks_path(page: 2)

      form = Nokogiri::HTML(response.body).at_css("form#tracks-search")
      expect(form.at_css("input[name='page']")).to be_nil
    end
  end

  describe "GET /tracks - DSL-Suche" do
    it "filtert über ein feld:wert-Kriterium (Intent 43)" do
      album = Album.create!(name: "Album", spotify_id: "alb-dsl-hit")
      Track.create!(name: "RSpec Jazz Track", spotify_id: "dsl-hit", album: album, genre: "RSpec Jazz",
                    duration_ms: 200_000)
      album_miss = Album.create!(name: "Album", spotify_id: "alb-dsl-miss")
      Track.create!(name: "RSpec Blues Track", spotify_id: "dsl-miss", album: album_miss, genre: "RSpec Blues",
                    duration_ms: 200_000)

      get tracks_path(q: "genre:jazz")

      names = Nokogiri::HTML(response.body).css("tbody tr th a").map(&:text)
      expect(names).to eq(["RSpec Jazz Track"])
    end

    it "zeigt einen Hilfehinweis mit Syntax-Beispielen im Suchformular" do
      get tracks_path

      hint = Nokogiri::HTML(response.body).at_css("form#tracks-search .search-syntax-hint")
      expect(hint.text).to include("genre:jazz")
    end
  end

  describe "GET /tracks/query_suggestions" do
    it "liefert Vorschläge als JSON" do
      album = Album.create!(name: "Album", spotify_id: "alb-qs")
      Track.create!(name: "A", spotify_id: "qs-a", album: album, genre: "RSpec Jazz", duration_ms: 200_000)

      get query_suggestions_tracks_path(term: "genre:ja")

      expect(response.parsed_body["suggestions"]).to eq(['genre:"RSpec Jazz"'])
    end
  end

  describe "GET /tracks - Verfügbarkeits-Filter" do
    before do
      create_track(name: "RSpec Vorhanden", spotify_id: "avail-hit")
      create_track(name: "RSpec Fehlend", spotify_id: "avail-miss")
    end

    it "zeigt nur heruntergeladene Tracks bei available=downloaded" do
      with_download_file("RSpec Artist - RSpec Vorhanden.m4a") do
        get tracks_path(available: "downloaded")
      end

      names = Nokogiri::HTML(response.body).css("tbody tr th a").map(&:text)
      expect(names).to eq(["RSpec Vorhanden"])
    end

    it "zeigt nur fehlende Tracks bei available=missing" do
      with_download_file("RSpec Artist - RSpec Vorhanden.m4a") do
        get tracks_path(available: "missing")
      end

      names = Nokogiri::HTML(response.body).css("tbody tr th a").map(&:text)
      expect(names).to eq(["RSpec Fehlend"])
    end

    it "zeigt alle Tracks bei unbekanntem available-Wert" do
      get tracks_path(available: "quatsch")

      names = Nokogiri::HTML(response.body).css("tbody tr th a").map(&:text)
      expect(names).to contain_exactly("RSpec Vorhanden", "RSpec Fehlend")
    end

    it "kombiniert den Filter mit Suche und Sortierung" do
      with_download_file("RSpec Artist - RSpec Vorhanden.m4a") do
        get tracks_path(available: "downloaded", q: "RSpec", sort: "name", direction: "asc")
      end

      names = Nokogiri::HTML(response.body).css("tbody tr th a").map(&:text)
      expect(names).to eq(["RSpec Vorhanden"])
    end

    it "paginiert das gefilterte Ergebnis korrekt" do
      with_download_file("RSpec Artist - RSpec Vorhanden.m4a") do
        get tracks_path(available: "downloaded")
      end

      rows = Nokogiri::HTML(response.body).css("tbody tr")
      expect(rows.size).to eq(1)
    end

    it "rendert das Filter-Dropdown mit dem aktuellen Wert vorausgewählt" do
      get tracks_path(available: "missing")

      selected = Nokogiri::HTML(response.body).at_css("select[name='available'] option[selected]")
      expect(selected[:value]).to eq("missing")
    end
  end

  describe "GET /tracks - Turbo Frame" do
    it "rendert die volle Seite inklusive Navbar bei einem normalen Request" do
      get tracks_path

      aggregate_failures do
        expect(response.body).to include("navbar-brand")
        expect(response.body).to include('id="tracks"')
      end
    end

    it "rendert nur den Frame-Inhalt ohne Navbar, wenn der Turbo-Frame-Header gesetzt ist" do
      get tracks_path, headers: { "Turbo-Frame" => "tracks" }

      aggregate_failures do
        expect(response.body).to_not include("navbar-brand")
        expect(response.body).to include('id="tracks"')
        expect(response.body).to include("<table")
      end
    end
  end

  describe "GET /tracks/:id" do
    it "liefert Erfolg" do
      track = create_track

      get track_path(track)

      expect(response).to have_http_status(:success)
    end

    it "lädt Album, Artists und Playlists für die Show ohne Lazy Loading" do
      album = Album.create!(name: "Album Show", spotify_id: "alb-show-1")
      artist = Artist.create!(name: "Artist Show", spotify_id: "art-show-1")
      playlist = Playlist.create!(spotify_id: "pl-show-1", name: "Fusion Show")
      track = Track.create!(name: "Track Show", spotify_id: "trk-show-1", album: album,
                            artists: [artist], duration_ms: 200_000)
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)

      queries = []
      callback = lambda do |_name, _start, _finish, _id, payload|
        queries << payload[:sql] unless payload[:name] == "SCHEMA"
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get track_path(track)
      end

      expect(response).to have_http_status(:success)
      aggregate_failures do
        expect(queries.count { |sql| sql.include?('FROM "albums"') }).to eq(1)
        expect(queries.count { |sql| sql.include?('FROM "artists"') }).to eq(2)
        expect(queries.count { |sql| sql.include?('FROM "playlists"') }).to eq(1)
      end
    end

    it "rendert die Playlist-Zeile inkl. Track-Anzahl, wenn der Track in einer Playlist ist" do
      track = create_track
      playlist = Playlist.create!(spotify_id: "pl-t1", name: "Fusion Badge")
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)

      get track_path(track)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("<td>1</td>")
    end
  end

  describe "GET / (recently_played_index)" do
    it "verwendet den angemeldeten User für recently_played" do
      current_spotify_user = users(:one).spotify_user
      other_spotify_user = users(:two).spotify_user
      allow(current_spotify_user).to receive(:recently_played).with(limit: 50).and_return([])
      expect(other_spotify_user).not_to receive(:recently_played)

      get root_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /tracks/download" do
    it "reiht DownloadMissingTracksJob ein und redirected sofort zu tracks_path" do
      allow(DownloadMissingTracksJob).to receive(:perform_later)

      post download_tracks_path

      expect(DownloadMissingTracksJob).to have_received(:perform_later)
      expect(response).to redirect_to(tracks_path)
    end

    it "zeigt einen Alert und startet keinen Job, wenn bereits ein Download läuft" do
      allow(DownloadMissingTracksJob).to receive(:perform_later)
      DownloadPlaylistService::DOWNLOAD_LOCK.lock
      begin
        post download_tracks_path
      ensure
        DownloadPlaylistService::DOWNLOAD_LOCK.unlock
      end

      expect(DownloadMissingTracksJob).to_not have_received(:perform_later)
      expect(response).to redirect_to(tracks_path)
      expect(flash[:alert]).to include("läuft bereits")
    end
  end

  describe "GET /tracks/:id/stream" do
    it "sendet die Datei, wenn track_path vorhanden ist" do
      track = create_track

      with_download_file("RSpec Artist - Song.m4a") do
        get stream_track_path(track)
      end

      expect(response).to have_http_status(:success)
    end

    it "kuendigt Range-Unterstuetzung an, auch ohne Range-Header" do
      track = create_track

      with_download_file("RSpec Artist - Song.m4a", content: "0123456789") do
        get stream_track_path(track)
      end

      expect(response.headers["Accept-Ranges"]).to eq("bytes")
    end

    it "liefert bei einem Range-Header nur den angeforderten Byte-Bereich (Status 206)" do
      track = create_track

      with_download_file("RSpec Artist - Song.m4a", content: "0123456789") do
        get stream_track_path(track), headers: { "Range" => "bytes=2-4" }
      end

      aggregate_failures do
        expect(response).to have_http_status(:partial_content)
        expect(response.headers["Content-Range"]).to eq("bytes 2-4/10")
        expect(response.body).to eq("234")
      end
    end
  end
end
