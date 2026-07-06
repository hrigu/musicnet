# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Playlists", type: :request do
  fixtures :users, :playlists

  let(:downloads_dir) { Rails.root.join("downloads/tracks") }

  def with_download_file(file_name)
    FileUtils.mkdir_p(downloads_dir)
    FileUtils.touch(downloads_dir.join(file_name))
    yield
  ensure
    FileUtils.rm_f(downloads_dir.join(file_name))
  end

  describe "ohne Login" do
    it "redirected zum Sign-in" do
      get playlists_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "mit Login" do
    before { sign_in users(:one) }

    it "GET /playlists liefert Erfolg" do
      get playlists_path

      expect(response).to have_http_status(:success)
    end

    it "GET /playlists zeigt einen 'Fetch all Playlists!'-Button oben auf der Seite (Intent 53)" do
      get playlists_path

      link = Nokogiri::HTML(response.body).at_css("a[href='#{fetch_all_playlists_path}']")
      expect(link).to_not be_nil
      expect(link.text.strip).to eq("Fetch all Playlists!")
      expect(link["data-turbo-method"]).to eq("post")
    end

    it "zeigt 'Fetch all Playlists!' nicht mehr in der Navbar (Intent 53)" do
      get playlists_path

      nav = Nokogiri::HTML(response.body).at_css("nav")
      expect(nav.text).to_not include("Fetch all Playlists!")
    end

    it "zeigt nur Playlists der aktiven Bibliothek, wenn eine gesetzt ist (Intent 57)" do
      blues = Library.create!(name: "Blues", keyword: "blues")
      users(:one).update!(active_library: blues)
      blues_playlist = Playlist.create!(spotify_id: "pl-cat-idx-blues", name: "RSpec Blues Session Idx")
      Playlist.create!(spotify_id: "pl-cat-idx-fusion", name: "RSpec Fusion Abende Idx")
      blues_playlist.libraries << blues

      get playlists_path

      names = Nokogiri::HTML(response.body).css("tbody tr td:nth-child(5) a").map(&:text)
      expect(names).to include("RSpec Blues Session Idx")
      expect(names).to_not include("RSpec Fusion Abende Idx")
    end

    it "GET /playlists zeigt die Track-Anzahl ohne eine COUNT-Query pro Playlist" do
      album = Album.create!(spotify_id: "alb-i1", name: "A Go Go")
      with_two = Playlist.create!(spotify_id: "pl-i1", name: "Fusion Zwei")
      Playlist.create!(spotify_id: "pl-i2", name: "Fusion Leer")
      2.times do |i|
        track = Track.create!(spotify_id: "trk-i#{i}", name: "Track #{i}", album: album, duration_ms: 200_000)
        PlaylistTrack.create!(playlist: with_two, track: track, added_at: Time.current)
      end

      queries = []
      callback = lambda do |_name, _start, _finish, _id, payload|
        queries << payload[:sql] unless payload[:name] == "SCHEMA"
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get playlists_path
      end

      expect(response).to have_http_status(:success)
      aggregate_failures do
        expect(queries.count { |sql| sql.include?('FROM "tracks"') }).to eq(0)
        expect(response.body).to include("<td>2</td>")
        expect(response.body).to include("<td>0</td>")
      end
    end

    it "zeigt die zugeordneten Bibliotheken ohne eine Query pro Playlist (Intent 57)" do
      blues = Library.create!(name: "Blues", keyword: "blues")
      fusion = Library.create!(name: "Fusion", keyword: "fusion")
      both = Playlist.create!(spotify_id: "pl-lib-idx", name: "RSpec Blues Fusion Idx")
      both.libraries << [blues, fusion]

      queries = []
      callback = lambda do |_name, _start, _finish, _id, payload|
        queries << payload[:sql] unless payload[:name] == "SCHEMA"
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get playlists_path
      end

      library_queries = queries.count do |sql|
        sql.include?('FROM "libraries"') || sql.include?('FROM "library_playlists"')
      end
      aggregate_failures do
        expect(library_queries).to be <= 2
        expect(response.body).to include("Blues, Fusion")
      end
    end

    it "GET /playlists/:id liefert Erfolg" do
      get playlist_path(playlists(:dark))

      expect(response).to have_http_status(:success)
    end

    it "GET /playlists/:id bleibt für einen anderen eingeloggten User sichtbar" do
      sign_out users(:one)
      sign_in users(:two)

      get playlist_path(playlists(:dark))

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Fusion Dark")
    end

    it "POST /playlists/fetch_all ruft BuildMusicNetService auf und leitet mit Zusammenfassung weiter" do
      info = BuildMusicNetService::ServiceInfo.new
      info.add_new_created_playlist("RSpec Neue Playlist")
      info.add_new_created_playlist("RSpec Zweite Playlist")
      info.add_new_created_track("RSpec Neuer Track")
      service = instance_double(BuildMusicNetService, build: info)
      allow(BuildMusicNetService).to receive(:new).and_return(service)

      post fetch_all_playlists_path

      expect(response).to redirect_to(playlists_path)
      expect(service).to have_received(:build)
      follow_redirect!
      expect(response.body).to include("2 Playlists neu")
      expect(response.body).to include("1 Tracks neu")

      notice = Nokogiri::HTML(response.body).at_css(".alert.alert-success")
      expect(notice.text).to include("2 Playlists neu")
    end

    it "POST /playlists/fetch_all zeigt eine Bestätigung, auch wenn sich nichts geändert hat" do
      info = BuildMusicNetService::ServiceInfo.new
      service = instance_double(BuildMusicNetService, build: info)
      allow(BuildMusicNetService).to receive(:new).and_return(service)

      post fetch_all_playlists_path
      follow_redirect!

      expect(response.body).to include("keine Änderungen")
    end

    it "GET /playlists/:id lädt tracks, artists und albums mit je genau einer Query" do
      album = Album.create!(spotify_id: "alb-n1", name: "A Go Go")
      artist = Artist.create!(spotify_id: "art-n1", name: "John Scofield")
      playlist = Playlist.create!(spotify_id: "pl-n1", name: "Fusion Query")
      other_playlist = Playlist.create!(spotify_id: "pl-n2", name: "Blues Query")
      3.times do |i|
        track = Track.create!(spotify_id: "trk-n#{i}", name: "Track #{i}", album: album,
                              artists: [artist], duration_ms: 200_000)
        PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
        PlaylistTrack.create!(playlist: other_playlist, track: track, added_at: Time.current)
      end

      queries = []
      callback = lambda do |_name, _start, _finish, _id, payload|
        queries << payload[:sql] unless payload[:name] == "SCHEMA"
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get playlist_path(playlist)
      end

      expect(response).to have_http_status(:success)
      aggregate_failures do
        expect(queries.count { |sql| sql.include?('FROM "tracks"') }).to eq(1)
        expect(queries.count { |sql| sql.include?('FROM "artists"') }).to eq(1)
        expect(queries.count { |sql| sql.include?('FROM "albums"') }).to eq(1)
      end
    end

    it "GET /playlists/:id lädt Audio-Elemente nicht automatisch (preload=none)" do
      album = Album.create!(spotify_id: "alb-p1", name: "A Go Go")
      playlist = Playlist.create!(spotify_id: "pl-p1", name: "Fusion Preload")
      track = Track.create!(spotify_id: "trk-p1", name: "Hottentot", album: album, duration_ms: 200_000)
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)

      with_download_file("RSpec Artist - Hottentot.m4a") do
        get playlist_path(playlist)
      end

      expect(response.body).to include('preload="none"')
      expect(response.body).to_not include('preload="false"')
    end

    it "GET /playlists/:id zeigt das Badge für Tracks ohne Soundfile" do
      album = Album.create!(spotify_id: "alb-b1", name: "A Go Go")
      playlist = Playlist.create!(spotify_id: "pl-b1", name: "Fusion Badge")
      track = Track.create!(spotify_id: "trk-b1", name: "RSpec Ohne File", album: album, duration_ms: 200_000)
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)

      get playlist_path(playlist)

      aggregate_failures do
        expect(response.body).to include("kein File")
        expect(response.body).to_not include("audio-trigger")
      end
    end

    it "GET /playlists/:id deaktiviert den Download-Button, wenn alle Tracks schon ein File haben" do
      album = Album.create!(spotify_id: "alb-d1", name: "A Go Go")
      playlist = Playlist.create!(spotify_id: "pl-d1", name: "Fusion Downloaded")
      track = Track.create!(spotify_id: "trk-d1", name: "RSpec Vorhanden", album: album, duration_ms: 200_000)
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)

      with_download_file("RSpec Artist - RSpec Vorhanden.m4a") do
        get playlist_path(playlist)
      end

      aggregate_failures do
        expect(response.body).to include("<button")
        expect(response.body).to include("disabled")
        expect(response.body).to_not include(download_playlist_path(playlist))
      end
    end

    it "GET /playlists/:id zeigt den aktiven Download-Button, wenn mindestens ein Track fehlt" do
      album = Album.create!(spotify_id: "alb-e1", name: "A Go Go")
      playlist = Playlist.create!(spotify_id: "pl-e1", name: "Fusion Missing")
      track = Track.create!(spotify_id: "trk-e1", name: "RSpec Fehlend", album: album, duration_ms: 200_000)
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)

      get playlist_path(playlist)

      expect(response.body).to include(download_playlist_path(playlist))
    end

    it "GET /playlists/:id löst die Track-Pfade mit einem einzigen Verzeichnis-Scan auf" do
      album = Album.create!(spotify_id: "alb-s1", name: "A Go Go")
      playlist = Playlist.create!(spotify_id: "pl-s1", name: "Fusion Scan")
      3.times do |i|
        track = Track.create!(spotify_id: "trk-s#{i}", name: "RSpec Scan #{i}", album: album, duration_ms: 200_000)
        PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
      end
      allow(Dir).to receive(:children).and_call_original

      get playlist_path(playlist)

      expect(Dir).to have_received(:children).with(TrackFileLocator.downloads_dir).at_most(:once)
    end

    it "GET /playlists/:id zeigt den Button zum Aktualisieren der Playlist" do
      playlist = playlists(:dark)

      get playlist_path(playlist)

      expect(response.body).to include(refresh_playlist_path(playlist))
      expect(response.body).to include("Playlist aktualisieren")
    end

    it "GET /playlists/:id zeigt, wann die Playlist zuletzt aktualisiert wurde" do
      playlist = playlists(:dark)

      get playlist_path(playlist)

      expect(response.body).to include(I18n.l(playlist.updated_at))
    end

    it "POST /playlists/:id/refresh ruft refresh_playlist auf, redirected und zeigt die Änderungen" do
      info = BuildMusicNetService::RefreshInfo.new(["Green Tea"], ["Hottentot"])
      service = instance_double(BuildMusicNetService, refresh_playlist: info)
      allow(BuildMusicNetService).to receive(:new).and_return(service)
      playlist = playlists(:dark)

      post refresh_playlist_path(playlist)

      expect(response).to redirect_to(playlist_path(playlist))
      expect(service).to have_received(:refresh_playlist).with(playlist)

      follow_redirect!

      expect(response.body).to include("Green Tea")
      expect(response.body).to include("Hottentot")
    end

    it "POST /playlists/:id/refresh zeigt einen Hinweis, wenn es keine Änderungen gibt" do
      info = BuildMusicNetService::RefreshInfo.new([], [])
      service = instance_double(BuildMusicNetService, refresh_playlist: info)
      allow(BuildMusicNetService).to receive(:new).and_return(service)

      post refresh_playlist_path(playlists(:dark))
      follow_redirect!

      expect(response.body).to include("Keine Änderungen")
    end

    it "POST /playlists/:id/refresh zeigt bei nicht mehr existierender Spotify-Playlist einen Alert" do
      service = instance_double(BuildMusicNetService)
      allow(service).to receive(:refresh_playlist)
        .and_raise(BuildMusicNetService::PlaylistNotFoundError, "Playlist 'Fusion Dark' wurde auf Spotify nicht gefunden")
      allow(BuildMusicNetService).to receive(:new).and_return(service)
      playlist = playlists(:dark)

      post refresh_playlist_path(playlist)

      expect(response).to redirect_to(playlist_path(playlist))
      expect(flash[:alert]).to include("nicht gefunden")
    end

    it "POST /playlists/fetch_all zeigt einen Alert, wenn bereits ein Sync läuft" do
      service = instance_double(BuildMusicNetService)
      allow(service).to receive(:build)
        .and_raise(BuildMusicNetService::SyncAlreadyRunningError, "Es läuft bereits ein Sync")
      allow(BuildMusicNetService).to receive(:new).and_return(service)

      post fetch_all_playlists_path

      expect(response).to redirect_to(playlists_path)
      expect(flash[:alert]).to include("läuft bereits")
    end

    it "POST /playlists/:id/refresh zeigt einen Alert, wenn bereits ein Sync läuft" do
      service = instance_double(BuildMusicNetService)
      allow(service).to receive(:refresh_playlist)
        .and_raise(BuildMusicNetService::SyncAlreadyRunningError, "Es läuft bereits ein Sync")
      allow(BuildMusicNetService).to receive(:new).and_return(service)
      playlist = playlists(:dark)

      post refresh_playlist_path(playlist)

      expect(response).to redirect_to(playlist_path(playlist))
      expect(flash[:alert]).to include("läuft bereits")
    end

    it "POST /playlists/:id/download ruft DownloadPlaylistService auf, redirected und zeigt das Ergebnis" do
      result = DownloadResultParser::Result.new(
        [{ name: "Minor Swing", provider: "YouTube" }],
        [{ name: "Sweet Life Blues", reason: "Kein Treffer gefunden" }]
      )
      service = instance_double(DownloadPlaylistService, download: result)
      allow(DownloadPlaylistService).to receive(:new).and_return(service)
      playlist = playlists(:dark)

      post download_playlist_path(playlist)

      expect(service).to have_received(:download)
      expect(response).to redirect_to(playlist_path(playlist))

      follow_redirect!

      expect(response.body).to include("Minor Swing")
      expect(response.body).to include("YouTube")
      expect(response.body).to include("Sweet Life Blues")
      expect(response.body).to include("Kein Treffer gefunden")
    end

    it "POST /playlists/:id/download begrenzt die Anzahl der im Flash gespeicherten Eintraege" do
      downloaded = Array.new(178) { |i| { name: "Track #{i}", provider: "YouTube" } }
      result = DownloadResultParser::Result.new(downloaded, [])
      service = instance_double(DownloadPlaylistService, download: result)
      allow(DownloadPlaylistService).to receive(:new).and_return(service)
      playlist = playlists(:dark)

      expect { post download_playlist_path(playlist) }.to_not raise_error
      follow_redirect!

      expect(response.body).to include("und 170 weitere")
    end

    it "POST /playlists/:id/download ueberschreitet das Cookie-Limit auch im Worst-Case nicht" do
      downloaded = Array.new(8) { |i| { name: "Ein Ziemlich Langer Tracktitel Nummer #{i}", provider: "YouTube" } }
      failed = Array.new(8) do |i|
        { name: "Noch Ein Langer Tracktitel #{i}", reason: "x" * 80 }
      end
      result = DownloadResultParser::Result.new(downloaded, failed)
      service = instance_double(DownloadPlaylistService, download: result)
      allow(DownloadPlaylistService).to receive(:new).and_return(service)
      playlist = playlists(:dark)

      expect { post download_playlist_path(playlist) }.to_not raise_error
      expect(response).to redirect_to(playlist_path(playlist))
    end

    it "POST /playlists/:id/download zeigt keinen Ergebnis-Alert, wenn der Download fehlschlägt" do
      service = instance_double(DownloadPlaylistService, download: nil)
      allow(DownloadPlaylistService).to receive(:new).and_return(service)
      playlist = playlists(:dark)

      post download_playlist_path(playlist)
      follow_redirect!

      expect(response.body).to_not include("Heruntergeladen")
    end

    it "POST /playlists/:id/download zeigt einen Alert, wenn bereits ein Download läuft" do
      service = instance_double(DownloadPlaylistService)
      allow(service).to receive(:download)
        .and_raise(DownloadPlaylistService::DownloadAlreadyRunningError, "Es läuft bereits ein Download")
      allow(DownloadPlaylistService).to receive(:new).and_return(service)
      playlist = playlists(:dark)

      post download_playlist_path(playlist)

      expect(response).to redirect_to(playlist_path(playlist))
      expect(flash[:alert]).to include("läuft bereits")
    end
  end
end
