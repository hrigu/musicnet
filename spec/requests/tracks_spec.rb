# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tracks", type: :request do
  fixtures :users

  let(:downloads_dir) { Rails.root.join("downloads/tracks") }

  def create_track(name: "Song", spotify_id: "trk1")
    album = Album.create!(name: "Album", spotify_id: "alb-#{spotify_id}")
    Track.create!(name: name, spotify_id: spotify_id, album: album, duration_ms: 200_000)
  end

  def with_download_file(file_name)
    FileUtils.mkdir_p(downloads_dir)
    FileUtils.touch(downloads_dir.join(file_name))
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
        expect(response.body).to_not include("<audio")
      end
    end

    it "zeigt den Player für Tracks mit Soundfile" do
      create_track

      with_download_file("RSpec Artist - Song.m4a") do
        get tracks_path
      end

      aggregate_failures do
        expect(response.body).to include("<audio")
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

  describe "GET /tracks/download" do
    it "ruft DownloadTrackService auf und redirected zu tracks_path" do
      service = instance_double(DownloadTrackService, download: true)
      allow(DownloadTrackService).to receive(:new).and_return(service)

      get download_tracks_path

      expect(service).to have_received(:download)
      expect(response).to redirect_to(tracks_path)
    end

    it "zeigt einen Alert, wenn bereits ein Download läuft" do
      service = instance_double(DownloadTrackService)
      allow(service).to receive(:download)
        .and_raise(DownloadPlaylistService::DownloadAlreadyRunningError, "Es läuft bereits ein Download")
      allow(DownloadTrackService).to receive(:new).and_return(service)

      get download_tracks_path

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
  end
end
