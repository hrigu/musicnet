# frozen_string_literal: true

require "rails_helper"
require "ostruct"

RSpec.describe "RecentlyPlayed", type: :request do
  fixtures :users

  before { sign_in users(:one) }
  # Default: "es laeuft gerade nichts" - verhindert, dass TracksController#prepend_now_playing
  # (GET /me/player, per RSpotify::User.oauth_get statt des kaputten RSpotify::User#player/Player
  # #track - siehe Kommentar dort) in jedem Test, der den Spotify-Tab rendert, einen echten
  # Spotify-API-Call ausloest. RSpotify::User.oauth_get ist eine Klassenmethode, der Stub gilt
  # daher unabhaengig davon, welches User-Objekt current_user im Controller konkret ist.
  before { allow(RSpotify::User).to receive(:oauth_get).with(anything, "me/player").and_return({ "is_playing" => false }) }

  def spotify_playback(name:, played_at:, artist_name:, album_name:, popularity:, id: SecureRandom.hex(8))
    OpenStruct.new(
      id:,
      played_at:,
      name:,
      popularity:,
      artists: [OpenStruct.new(name: artist_name)],
      album: OpenStruct.new(name: album_name)
    )
  end

  # Rohe JSON-Form von GET /me/player, wie sie RSpotify::User.oauth_get zurueckgibt (kein
  # RSpotify::Track/Player-Objekt) - siehe Kommentar bei TracksController#prepend_now_playing, warum
  # ueber den rohen Response statt ueber RSpotify::Player#track gearbeitet wird.
  def now_playing_response(id:, name:, artist_name:, album_name:, popularity:, currently_playing_type: "track")
    {
      "is_playing" => true,
      "currently_playing_type" => currently_playing_type,
      "item" => {
        "id" => id,
        "name" => name,
        "popularity" => popularity,
        "artists" => [{ "name" => artist_name }],
        "album" => { "name" => album_name }
      }
    }
  end

  def create_recent_track(name:, spotify_id:, artist_name:)
    album = Album.create!(name: "Album #{spotify_id}", spotify_id: "alb-#{spotify_id}")
    artist = Artist.create!(name: artist_name, spotify_id: "art-#{spotify_id}")
    Track.create!(name:, spotify_id:, album:, artists: [artist], duration_ms: 200_000)
  end

  describe "GET / (recently_played_index)" do
    it "zeigt standardmässig den Musicnet-Tab aktiv" do
      get root_path

      document = Nokogiri::HTML(response.body)
      active_tab = document.css(".nav-tabs .nav-link.active").map(&:text)

      aggregate_failures do
        expect(response).to have_http_status(:success)
        expect(active_tab).to eq(["Musicnet"])
      end
    end

    it "zeigt lokale Musicnet-Playbacks getrennt von anderen Usern" do
      own_track = create_recent_track(name: "RSpec Local Playback", spotify_id: "recent-local-own",
                                      artist_name: "RSpec Artist Local")
      other_track = create_recent_track(name: "RSpec Fremdes Playback", spotify_id: "recent-local-other",
                                        artist_name: "RSpec Artist Other")
      DjSessionPlayback.create!(user: users(:one), track: own_track, played_at: Time.zone.parse("2026-07-09 20:00:00"))
      DjSessionPlayback.create!(user: users(:two), track: other_track, played_at: Time.zone.parse("2026-07-09 21:00:00"))

      get root_path

      aggregate_failures do
        expect(response.body).to include("RSpec Local Playback")
        expect(response.body).to_not include("RSpec Fremdes Playback")
      end
    end

    it "gruppiert nah beieinander liegende Musicnet-Playbacks in eine Session" do
      first_track = create_recent_track(name: "RSpec Naheliegend Track 1", spotify_id: "recent-close-1",
                                        artist_name: "RSpec Naheliegend Artist")
      second_track = create_recent_track(name: "RSpec Naheliegend Track 2", spotify_id: "recent-close-2",
                                         artist_name: "RSpec Naheliegend Artist")
      DjSessionPlayback.create!(user: users(:one), track: first_track, played_at: Time.zone.parse("2026-07-09 20:00:00"))
      DjSessionPlayback.create!(user: users(:one), track: second_track, played_at: Time.zone.parse("2026-07-09 20:20:00"))

      get root_path

      document = Nokogiri::HTML(response.body)

      expect(document.css("tr.dj-session-header").size).to eq(1)
    end

    it "verwendet die korrekte deutsche Mehrzahl 'Titel' statt 'Titels' in der Session-Kopfzeile" do
      first_track = create_recent_track(name: "RSpec Mehrzahl Track 1", spotify_id: "recent-plural-1",
                                        artist_name: "RSpec Mehrzahl Artist")
      second_track = create_recent_track(name: "RSpec Mehrzahl Track 2", spotify_id: "recent-plural-2",
                                         artist_name: "RSpec Mehrzahl Artist")
      DjSessionPlayback.create!(user: users(:one), track: first_track, played_at: Time.zone.parse("2026-07-09 20:00:00"))
      DjSessionPlayback.create!(user: users(:one), track: second_track, played_at: Time.zone.parse("2026-07-09 20:20:00"))

      get root_path

      aggregate_failures do
        expect(response.body).to include("2 Titel")
        expect(response.body).to_not include("Titels")
      end
    end

    it "startet eine neue Session, wenn zwischen zwei Musicnet-Playbacks eine grosse Luecke liegt" do
      first_track = create_recent_track(name: "RSpec Entfernt Track 1", spotify_id: "recent-far-1",
                                        artist_name: "RSpec Entfernt Artist")
      second_track = create_recent_track(name: "RSpec Entfernt Track 2", spotify_id: "recent-far-2",
                                         artist_name: "RSpec Entfernt Artist")
      DjSessionPlayback.create!(user: users(:one), track: first_track, played_at: Time.zone.parse("2026-07-09 12:00:00"))
      DjSessionPlayback.create!(user: users(:one), track: second_track, played_at: Time.zone.parse("2026-07-09 20:00:00"))

      get root_path

      document = Nokogiri::HTML(response.body)

      expect(document.css("tr.dj-session-header").size).to eq(2)
    end

    it "zeigt einen aufgeloesten Ortsnamen statt Rohkoordinaten" do
      track = create_recent_track(name: "RSpec Ort Aufgeloest", spotify_id: "recent-location-resolved",
                                  artist_name: "RSpec Ort Artist")
      DjSessionPlayback.create!(user: users(:one), track:, played_at: Time.zone.parse("2026-07-09 20:00:00"),
                                latitude: 47.376887, longitude: 8.541694, location_name: "Zürich")

      get root_path

      aggregate_failures do
        expect(response.body).to include("Zürich")
        expect(response.body).to_not include("47.376887")
      end
    end

    it "zeigt Rohkoordinaten als Fallback, solange kein Ortsname aufgeloest ist" do
      track = create_recent_track(name: "RSpec Ort Ausstehend", spotify_id: "recent-location-pending",
                                  artist_name: "RSpec Ort Artist Pending")
      DjSessionPlayback.create!(user: users(:one), track:, played_at: Time.zone.parse("2026-07-09 20:00:00"),
                                latitude: 47.376887, longitude: 8.541694)

      get root_path

      expect(response.body).to include("47.376887")
    end

    it "abonniert den downloads-Kanal, damit Import+Download eines Spotify-Tracks live rueckmelden" do
      get root_path

      expect(response.body).to include('id="download-log"')
    end

    it "verwendet den angemeldeten User für recently_played im Spotify-Tab" do
      current_spotify_user = users(:one).spotify_user
      other_spotify_user = users(:two).spotify_user
      allow(current_spotify_user).to receive(:recently_played).with(limit: 50).and_return([])
      expect(other_spotify_user).not_to receive(:recently_played)

      get root_path(tab: "spotify")

      expect(response).to have_http_status(:success)
    end

    it "zeigt die Recently-Played-Liste weiterhin an, wenn /me/player mit 401 fehlschlaegt (fehlender Scope bei alter Session)" do
      current_spotify_user = users(:one).spotify_user
      playback = spotify_playback(id: "recent-despite-401", name: "RSpec Trotz 401", played_at: "2026-07-09T22:00:00Z",
                                  artist_name: "RSpec Trotz 401 Artist", album_name: "RSpec Trotz 401 Album", popularity: 20)
      allow(current_spotify_user).to receive(:recently_played).with(limit: 50).and_return([playback])
      allow(RSpotify::User).to receive(:oauth_get).with(anything, "me/player")
                                                  .and_raise(RestClient::Unauthorized.new(double(code: 401, body: "")))

      get root_path(tab: "spotify")

      aggregate_failures do
        expect(response).to have_http_status(:success)
        expect(response.body).to include("RSpec Trotz 401")
      end
    end

    it "zeigt die Recently-Played-Liste weiterhin an, wenn gerade Werbung statt eines Tracks laeuft" do
      current_spotify_user = users(:one).spotify_user
      playback = spotify_playback(id: "recent-despite-ad", name: "RSpec Trotz Werbung", played_at: "2026-07-09T22:00:00Z",
                                  artist_name: "RSpec Trotz Werbung Artist", album_name: "RSpec Trotz Werbung Album", popularity: 20)
      allow(current_spotify_user).to receive(:recently_played).with(limit: 50).and_return([playback])
      allow(RSpotify::User).to receive(:oauth_get).with(anything, "me/player").and_return(
        now_playing_response(id: "ad-1", name: "Werbung", artist_name: "-", album_name: "-", popularity: 0,
                             currently_playing_type: "ad")
      )

      get root_path(tab: "spotify")

      aggregate_failures do
        expect(response).to have_http_status(:success)
        expect(response.body).to include("RSpec Trotz Werbung")
        expect(response.body).to_not include("läuft gerade")
      end
    end

    it "zeigt Spotify-Playbacks nur im Spotify-Tab" do
      current_spotify_user = users(:one).spotify_user
      playback = spotify_playback(name: "RSpec Spotify Playback", played_at: "2026-07-09T22:00:00Z",
                                  artist_name: "RSpec Spotify Artist", album_name: "RSpec Spotify Album",
                                  popularity: 77)
      allow(current_spotify_user).to receive(:recently_played).with(limit: 50).and_return([playback])

      get root_path(tab: "spotify")

      aggregate_failures do
        expect(response.body).to include("RSpec Spotify Playback")
        expect(response.body).to include("RSpec Spotify Artist")
        expect(response.body).to include("RSpec Spotify Album")
        expect(response.body).to include("77")
      end
    end

    it "verlinkt einen Spotify-Track, der bereits lokal existiert, auf seine Detailseite" do
      current_spotify_user = users(:one).spotify_user
      local_track = create_recent_track(name: "RSpec Bereits Lokal", spotify_id: "recent-already-local",
                                        artist_name: "RSpec Bereits Lokal Artist")
      playback = spotify_playback(id: "recent-already-local", name: "RSpec Bereits Lokal", played_at: "2026-07-09T22:00:00Z",
                                  artist_name: "RSpec Bereits Lokal Artist", album_name: "RSpec Bereits Lokal Album",
                                  popularity: 42)
      allow(current_spotify_user).to receive(:recently_played).with(limit: 50).and_return([playback])

      get root_path(tab: "spotify")

      aggregate_failures do
        expect(response.body).to include(track_path(local_track))
        expect(response.body).to include("in Musicnet")
      end
    end

    it "bietet fuer einen noch nicht lokalen Spotify-Track keinen Link, sondern reinen Text" do
      current_spotify_user = users(:one).spotify_user
      playback = spotify_playback(id: "recent-not-local", name: "RSpec Noch Nicht Lokal", played_at: "2026-07-09T22:00:00Z",
                                  artist_name: "RSpec Noch Nicht Lokal Artist", album_name: "RSpec Noch Nicht Lokal Album",
                                  popularity: 13)
      allow(current_spotify_user).to receive(:recently_played).with(limit: 50).and_return([playback])

      get root_path(tab: "spotify")

      document = Nokogiri::HTML(response.body)
      matching_links = document.css("a").select { |a| a.text.strip == "RSpec Noch Nicht Lokal" }
      aggregate_failures do
        expect(response.body).to include("RSpec Noch Nicht Lokal")
        expect(matching_links).to be_empty
      end
    end

    it "zeigt einen Vorhören-Button mit Spotify-Embed fuer einen noch nicht heruntergeladenen Track" do
      current_spotify_user = users(:one).spotify_user
      playback = spotify_playback(id: "recent-vorhoeren-fehlt", name: "RSpec Vorhoeren Noetig", played_at: "2026-07-09T22:00:00Z",
                                  artist_name: "RSpec Vorhoeren Artist", album_name: "RSpec Vorhoeren Album", popularity: 8)
      allow(current_spotify_user).to receive(:recently_played).with(limit: 50).and_return([playback])

      get root_path(tab: "spotify")

      aggregate_failures do
        expect(response.body).to include("🎧 Vorhören")
        expect(response.body).to include("open.spotify.com/embed/track/recent-vorhoeren-fehlt")
      end
    end

    it "zeigt keinen Vorhören-Button, wenn der Track bereits heruntergeladen ist" do
      current_spotify_user = users(:one).spotify_user
      local_track = create_recent_track(name: "RSpec Bereits Heruntergeladen", spotify_id: "recent-schon-da",
                                        artist_name: "RSpec Bereits Heruntergeladen Artist")
      FileUtils.mkdir_p(Rails.root.join("downloads/tracks"))
      FileUtils.touch(Rails.root.join("downloads/tracks/RSpec Bereits Heruntergeladen Artist - RSpec Bereits Heruntergeladen.m4a"))
      playback = spotify_playback(id: "recent-schon-da", name: "RSpec Bereits Heruntergeladen", played_at: "2026-07-09T22:00:00Z",
                                  artist_name: "RSpec Bereits Heruntergeladen Artist", album_name: "RSpec Bereits Heruntergeladen Album",
                                  popularity: 8)
      allow(current_spotify_user).to receive(:recently_played).with(limit: 50).and_return([playback])

      begin
        get root_path(tab: "spotify")
      ensure
        FileUtils.rm_f(Rails.root.join("downloads/tracks/RSpec Bereits Heruntergeladen Artist - RSpec Bereits Heruntergeladen.m4a"))
      end

      aggregate_failures do
        expect(response.body).to include(track_path(local_track))
        expect(response.body).to_not include("🎧 Vorhören")
      end
    end

    it "zeigt einen Spinner statt des Buttons, waehrend Import+Download fuer diesen Track noch laeuft" do
      current_spotify_user = users(:one).spotify_user
      playback = spotify_playback(id: "recent-pending", name: "RSpec Noch Am Laufen", played_at: "2026-07-09T22:00:00Z",
                                  artist_name: "RSpec Noch Am Laufen Artist", album_name: "RSpec Noch Am Laufen Album",
                                  popularity: 5)
      allow(current_spotify_user).to receive(:recently_played).with(limit: 50).and_return([playback])
      PendingSpotifyImports.add("recent-pending")

      begin
        get root_path(tab: "spotify")
      ensure
        PendingSpotifyImports.remove("recent-pending")
      end

      aggregate_failures do
        expect(response.body).to include("wird heruntergeladen")
        expect(response.body).to_not include("Herunterladen")
      end
    end

    it "zeigt weiterhin den Spinner statt 'in Musicnet', wenn der Track schon importiert aber noch nicht fertig heruntergeladen ist" do
      current_spotify_user = users(:one).spotify_user
      local_track = create_recent_track(name: "RSpec Importiert Aber Laeuft Noch", spotify_id: "recent-imported-still-pending",
                                        artist_name: "RSpec Importiert Artist")
      playback = spotify_playback(id: "recent-imported-still-pending", name: "RSpec Importiert Aber Laeuft Noch",
                                  played_at: "2026-07-09T22:00:00Z", artist_name: "RSpec Importiert Artist",
                                  album_name: "RSpec Importiert Album", popularity: 5)
      allow(current_spotify_user).to receive(:recently_played).with(limit: 50).and_return([playback])
      PendingSpotifyImports.add("recent-imported-still-pending")

      begin
        get root_path(tab: "spotify")
      ensure
        PendingSpotifyImports.remove("recent-imported-still-pending")
      end

      aggregate_failures do
        expect(response.body).to include("wird heruntergeladen")
        expect(response.body).to_not include("in Musicnet")
        expect(response.body).to include(track_path(local_track))
      end
    end

    it "stellt den aktuell auf Spotify laufenden Track dem Spotify-Tab voran und markiert ihn" do
      current_spotify_user = users(:one).spotify_user
      recent_playback = spotify_playback(id: "recent-past", name: "RSpec Frueher Gespielt", played_at: "2026-07-09T20:00:00Z",
                                         artist_name: "RSpec Frueher Artist", album_name: "RSpec Frueher Album", popularity: 10)
      allow(current_spotify_user).to receive(:recently_played).with(limit: 50).and_return([recent_playback])
      allow(RSpotify::User).to receive(:oauth_get).with(anything, "me/player").and_return(
        now_playing_response(id: "recent-now-playing", name: "RSpec Laeuft Gerade",
                             artist_name: "RSpec Laeuft Gerade Artist", album_name: "RSpec Laeuft Gerade Album", popularity: 50)
      )

      get root_path(tab: "spotify")

      document = Nokogiri::HTML(response.body)
      titles_in_order = document.css("tbody tr td:nth-child(2)").map { |td| td.text.strip }

      aggregate_failures do
        expect(response.body).to include("läuft gerade")
        expect(titles_in_order).to eq(["RSpec Laeuft Gerade", "RSpec Frueher Gespielt"])
      end
    end

    it "stellt den aktuell laufenden Track nicht doppelt voran, wenn er schon zuoberst in Recently-Played steht" do
      current_spotify_user = users(:one).spotify_user
      playback = spotify_playback(id: "recent-same", name: "RSpec Bereits Oben", played_at: "2026-07-09T22:00:00Z",
                                  artist_name: "RSpec Bereits Oben Artist", album_name: "RSpec Bereits Oben Album", popularity: 30)
      allow(current_spotify_user).to receive(:recently_played).with(limit: 50).and_return([playback])
      allow(RSpotify::User).to receive(:oauth_get).with(anything, "me/player").and_return(
        now_playing_response(id: "recent-same", name: "RSpec Bereits Oben",
                             artist_name: "RSpec Bereits Oben Artist", album_name: "RSpec Bereits Oben Album", popularity: 30)
      )

      get root_path(tab: "spotify")

      document = Nokogiri::HTML(response.body)
      # :not(.collapse) blendet die auf-/zuklappbare Vorhören-Zeile aus (der Track ist hier nicht
      # heruntergeladen, bekommt also einen Vorhören-Button samt eigener Embed-Zeile) - gezaehlt
      # werden soll nur, ob der Track als sichtbare Tabellenzeile nicht doppelt auftaucht.
      rows = document.css("tbody tr:not(.collapse)")

      aggregate_failures do
        expect(rows.size).to eq(1)
        expect(response.body).to include("läuft gerade")
      end
    end
  end
end
