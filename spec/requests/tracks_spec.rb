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

    it "zeigt das Suchfeld mit ausreichender Breite für die DSL (Intent 45)" do
      get tracks_path

      field = Nokogiri::HTML(response.body).at_css("input[name='q']")
      expect(field[:class]).to include("search-query-input")
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

  describe "GET /tracks - Aktive Bibliothek (Intent 57)" do
    def create_track_in_playlist(name:, spotify_id:, playlist_name:, playlist_spotify_id:, library: nil)
      track = create_track(name: name, spotify_id: spotify_id)
      playlist = Playlist.find_or_create_by!(name: playlist_name) { |p| p.spotify_id = playlist_spotify_id }
      playlist.libraries << library if library
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
      track
    end

    it "zeigt alle Tracks, wenn keine Bibliothek aktiv ist (Standard = 'Alle')" do
      create_track_in_playlist(name: "RSpec Blues Cat A", spotify_id: "cat-idx-a",
                               playlist_name: "RSpec Blues Session Idx", playlist_spotify_id: "pl-cat-idx-blues")
      create_track_in_playlist(name: "RSpec Fusion Cat B", spotify_id: "cat-idx-b",
                               playlist_name: "RSpec Fusion Abende Idx", playlist_spotify_id: "pl-cat-idx-fusion")

      get tracks_path

      names = Nokogiri::HTML(response.body).css("tbody tr th a").map(&:text)
      expect(names).to contain_exactly("RSpec Blues Cat A", "RSpec Fusion Cat B")
    end

    it "zeigt nur Tracks aus Playlists der aktiven Bibliothek, kombiniert mit Suche" do
      blues = Library.create!(name: "Blues", keyword: "blues")
      users(:one).update!(active_library: blues)
      create_track_in_playlist(name: "RSpec Blues Cat Match", spotify_id: "cat-idx-match",
                               playlist_name: "RSpec Blues Session Idx2", playlist_spotify_id: "pl-cat-idx2-blues",
                               library: blues)
      create_track_in_playlist(name: "RSpec Fusion Cat Miss", spotify_id: "cat-idx-miss",
                               playlist_name: "RSpec Fusion Abende Idx2", playlist_spotify_id: "pl-cat-idx2-fusion")

      get tracks_path(q: "RSpec")

      names = Nokogiri::HTML(response.body).css("tbody tr th a").map(&:text)
      expect(names).to eq(["RSpec Blues Cat Match"])
    end
  end

  describe "GET /tracks/query_suggestions" do
    it "liefert Vorschläge als JSON" do
      album = Album.create!(name: "Album", spotify_id: "alb-qs")
      Track.create!(name: "A", spotify_id: "qs-a", album: album, genre: "RSpec Jazz", duration_ms: 200_000)

      get query_suggestions_tracks_path(term: "genre:ja")

      expect(response.parsed_body["suggestions"]).to eq(['genre:"RSpec Jazz"'])
    end

    it "schlägt nur Playlists der aktiven Bibliothek vor (Intent 55/57)" do
      fusion = Library.create!(name: "Fusion", keyword: "fusion")
      users(:one).update!(active_library: fusion)
      Playlist.create!(name: "RSpec Zzyzu Blues Runde", spotify_id: "pl-qs-cat-blues")
      fusion_playlist = Playlist.create!(name: "RSpec Zzyzu Fusion Runde", spotify_id: "pl-qs-cat-fusion")
      fusion_playlist.libraries << fusion

      get query_suggestions_tracks_path(term: "playlist:zzyzu")

      expect(response.parsed_body["suggestions"]).to eq(['playlist:"RSpec Zzyzu Fusion Runde"'])
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

    it "zeigt Album-Name und Release-Datum gelabelt (Intent 64 Nachtrag)" do
      album = Album.create!(name: "RSpec Album Show", spotify_id: "alb-label-1", release_date: Date.new(2020, 5, 1))
      track = Track.create!(name: "Track", spotify_id: "trk-label-1", album: album, duration_ms: 200_000)

      get track_path(track)

      text = Nokogiri::HTML(response.body).at_css(".text-muted").text.squish
      expect(text).to eq("Album: RSpec Album Show von #{I18n.l(Date.new(2020, 5, 1))}")
    end

    it "zeigt nur den Album-Namen, wenn kein Release-Datum vorhanden ist (Intent 64 Nachtrag)" do
      album = Album.create!(name: "RSpec Album Ohne Datum", spotify_id: "alb-label-2")
      track = Track.create!(name: "Track", spotify_id: "trk-label-2", album: album, duration_ms: 200_000)

      get track_path(track)

      expect(response.body).to include("Album: RSpec Album Ohne Datum")
      expect(response.body).to_not include(" von ")
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
        expect(queries.count { |sql| sql.include?('FROM "artists"') }).to eq(1)
        expect(queries.count { |sql| sql.include?('FROM "playlist_tracks"') }).to eq(1)
        expect(queries.count { |sql| sql.include?('FROM "playlists"') }).to eq(1)
      end
    end

    it "zeigt eine Playlist als Element mit Badge und Hinzugefügt-Datum (Intent 64)" do
      track = create_track
      playlist = Playlist.create!(spotify_id: "pl-t1", name: "Fusion Badge")
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Date.new(2026, 1, 15))

      get track_path(track)

      html = Nokogiri::HTML(response.body)
      aggregate_failures do
        expect(response).to have_http_status(:success)
        expect(html.css("table")).to be_empty
        badges = html.css(".badge").map(&:text)
        expect(badges).to include("F_Badge")
        expect(response.body).to include(I18n.l(Date.new(2026, 1, 15)))
      end
    end

    it "umrahmt Playlist-Badge und Hinzugefügt-Datum als eine Einheit (Intent 64 Nachtrag)" do
      track = create_track
      playlist = Playlist.create!(spotify_id: "pl-frame-1", name: "Fusion Frame")
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Date.new(2026, 1, 15))

      get track_path(track)

      frame = Nokogiri::HTML(response.body).css(".border").find { |el| el.text.include?("F_Frame") }
      expect(frame).to be_present
    end

    it "zeigt eine Playlist ohne Datum, wenn added_at fehlt (Intent 64)" do
      track = create_track
      playlist = Playlist.create!(spotify_id: "pl-t2", name: "Fusion Kein Datum")
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: nil)

      get track_path(track)

      expect(response).to have_http_status(:success)
      badges = Nokogiri::HTML(response.body).css(".badge").map(&:text)
      expect(badges).to include("F_KeinDatum")
    end

    it "zeigt Künstler nur mit Namen als Elemente statt als Tabelle (Intent 64)" do
      album = Album.create!(name: "Album", spotify_id: "alb-artist-el")
      artist = Artist.create!(name: "RSpec Element Artist", spotify_id: "art-el-1", popularity: 42)
      track = Track.create!(name: "Track", spotify_id: "trk-artist-el", album: album,
                            artists: [artist], duration_ms: 200_000)

      get track_path(track)

      html = Nokogiri::HTML(response.body)
      aggregate_failures do
        expect(html.css("table")).to be_empty
        expect(html.css("a").map(&:text)).to include("RSpec Element Artist")
      end
    end

    it "zeigt Energie und Tempo als Meter/BPM statt der alten Audio-Features-Liste (Intent 64)" do
      track = create_track
      track.update!(audio_features: { "tempo" => 128.4, "energy" => 0.734 })

      get track_path(track)

      html = Nokogiri::HTML(response.body)
      aggregate_failures do
        expect(response.body).to_not include("Acousticness")
        expect(response.body).to include("128 <span class=\"small text-muted\">BPM</span>")
        expect(html.at_css(".track-meter .progress-bar")).to be_present
      end
    end

    it "zeigt den Dateinamen, wenn file_name gesetzt ist (Intent 73)" do
      track = create_track
      track.update_column(:file_name, "RSpec Artist - RSpec Song.m4a")

      get track_path(track)

      labels = Nokogiri::HTML(response.body).css(".text-muted.small").map(&:text)
      aggregate_failures do
        expect(labels).to include("Datei")
        expect(response.body).to include("RSpec Artist - RSpec Song.m4a")
      end
    end

    it "zeigt kein Dateiname-Feld, wenn file_name leer ist (Intent 73)" do
      track = create_track

      get track_path(track)

      labels = Nokogiri::HTML(response.body).css(".text-muted.small").map(&:text)
      expect(labels).to_not include("Datei")
    end

    it "labelt Dauer, Genre, Energie und Tempo (Intent 64 Nachtrag)" do
      track = create_track
      track.update!(audio_features: { "tempo" => 128.4, "energy" => 0.734 })
      track.update_column(:genre, "RSpec Deep House")

      get track_path(track)

      labels = Nokogiri::HTML(response.body).css(".text-muted.small").map(&:text)
      aggregate_failures do
        expect(labels).to include("Dauer")
        expect(labels).to include("Genre")
        expect(labels).to include("Energie")
        expect(labels).to include("Tempo")
      end
    end

    it "zeigt die Dauer des Tracks (Intent 64 Nachtrag)" do
      track = create_track

      get track_path(track)

      expect(response.body).to include(track.dauer)
    end

    it "zeigt keine Künstler des Albums mehr (Intent 64 Nachtrag)" do
      album = Album.create!(name: "Album", spotify_id: "alb-no-album-artists")
      album_artist = Artist.create!(name: "RSpec Album Only Artist", spotify_id: "art-album-only")
      Track.create!(name: "Anderer Track", spotify_id: "trk-other-album-track", album: album,
                    artists: [album_artist], duration_ms: 200_000)
      track = Track.create!(name: "Track", spotify_id: "trk-no-album-artists", album: album, duration_ms: 200_000)

      get track_path(track)

      aggregate_failures do
        expect(response.body).to_not include("Künstler des Albums")
        expect(response.body).to_not include("RSpec Album Only Artist")
      end
    end

    it "zeigt die Spotify-Einbettung, solange der Track noch nicht heruntergeladen ist (Intent 64)" do
      track = create_track

      get track_path(track)

      expect(response.body).to include("open.spotify.com/embed")
    end

    it "zeigt keine Spotify-Einbettung mehr, sobald der Track heruntergeladen ist (Intent 64)" do
      track = create_track

      with_download_file("RSpec Artist - Song.m4a") do
        get track_path(track)
      end

      expect(response.body).to_not include("open.spotify.com/embed")
    end

    it "zeigt das Genre als Badge (Intent 64)" do
      track = create_track
      track.update_column(:genre, "RSpec Deep House")

      get track_path(track)

      badges = Nokogiri::HTML(response.body).css(".badge").map(&:text)
      expect(badges).to include("RSpec Deep House")
    end

    it "verlinkt das Genre auf die gefilterte Tracks-Seite (Intent 64 Nachtrag)" do
      track = create_track
      track.update_column(:genre, "RSpec Deep House")

      get track_path(track)

      link = Nokogiri::HTML(response.body).css("a").find { |a| a.text.include?("RSpec Deep House") }
      expect(link[:href]).to eq(tracks_path(q: 'genre:"RSpec Deep House"'))
    end

    it "verlinkt das Genre nicht, wenn keins vorhanden ist (Intent 64 Nachtrag)" do
      track = create_track

      get track_path(track)

      html = Nokogiri::HTML(response.body)
      genre_label = html.css("div.text-muted.small").find { |el| el.text == "Genre" }
      genre_container = genre_label.parent
      expect(genre_container.css("a")).to be_empty
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
