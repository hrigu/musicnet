# Diary
## 2026-07-06
* Grosses Feature: Intent 57 - konfigurierbare "Bibliotheken" (`Library`-Model, Name + Stichwort)
  ersetzen die bisher hardcoded Blues/Fusion-Unterscheidung, sowohl für den Spotify-Import-Filter
  (`SpotifyPlaylistsGateway#owned_library_playlist?`) als auch für den Anzeige-Filter
  (`User#active_library_id` ersetzt den alten `active_playlist_category`-Enum aus Intent 54). Eine
  Playlist kann jetzt mehreren Bibliotheken gleichzeitig angehören (echte n:m-Beziehung statt
  Single-Select). `Library.matching(name)` ist die einzige Stelle mit der
  Stichwort-Teilstring-Logik - sowohl Import als auch automatische Zuordnung nutzen nur diese.
* Manuell beim Ausprobieren gefunden: eine neu angelegte Bibliothek ("Salsadancers", Stichwort
  "salsa") zeigte trotz mehrerer bereits importierter "...Salsa..."-Playlists 0 Treffer - die
  automatische Zuordnung griff bisher nur beim Spotify-Sync, nie rückwirkend auf schon vorhandene
  Playlists. Fix: `Library#resync_playlist_assignments!`, aufgerufen beim Anlegen/Bearbeiten einer
  Bibliothek über die neue Verwaltungsseite (`/libraries`).
* Beim Anzeigen der zugeordneten Bibliotheken auf `/playlists` eine Regression entdeckt:
  `TracksController#show` nutzt dasselbe `_playlist.erb`-Partial (für "Playlists die diesen Track
  enthalten") und brauchte darum denselben `libraries`-Preload, sonst `StrictLoadingViolationError`.
* Bug (nicht von mir eingeführt, beim Ausprobieren aufgefallen): "Alle Playlists holen" zeigte nach
  dem Sync gar kein Feedback - `PlaylistsController#fetch_all` rendert nach dem POST-Request direkt
  eine Debug-Seite statt umzuleiten, genau das Turbo/Rails-Anti-Pattern, das CLAUDE.md selbst unter
  "Sync flow" dokumentiert (Intent 37) und das bei `refresh`/`download` damals schon behoben wurde,
  bei `fetch_all` aber offenbar nie. Fix: Redirect mit einer kompakten Anzahl-Zusammenfassung
  ("3 Playlists neu, 1 Tracks neu") statt Namenslisten - ein Erstimport kann tausende Namen
  umfassen (Intent 33), das würde das ~4KB-Flash-Cookie-Limit sprengen.
* Dabei gleich noch eine app-weite Alt-Baustelle mitgenommen: `notice`/`alert` waren im Layout
  simple, unstylte `<p>`-Tags ohne Bootstrap-Klasse, ohne Container - klebten am linken Rand.
  Jetzt echte Bootstrap-`.alert`-Boxen (grün/rot), nur gerendert wenn tatsächlich Inhalt da ist.
* Kleines Polishing: die "Download"-Spalte auf `/playlists` war zugleich die einzige Stelle mit dem
  vollen Playlist-Namen (Spalte 1 zeigt nur ein gekürztes, farbcodiertes Badge) - durch reinen
  Klartext-Namen ersetzt, Download bleibt über die Playlist-Detailseite erreichbar.
* Wiederkehrende Falle heute: `git mv` einer Intent-Datei mit noch unstaged Änderungen hat mehrfach
  den *letzten committeten* Stand gestaged statt den aktuellen Working-Tree-Stand - Checkbox-Updates
  gingen dadurch zweimal beim Verschieben nach `completed/` verloren, erst ein erneutes `git add`
  auf die Datei hat den echten Stand erfasst. Im Zweifel nach einem `git mv` auf eine gerade
  bearbeitete Datei den Diff nochmal gegenprüfen.

## 2026-07-05
* Kurioser Bug beim Ausprobieren: die Login-Seite (Devise) warf `MissingTemplate` für
  `devise/queue_entries/_queue_entry`, sobald die Song-Queue nicht leer war. Ursache: Rails'
  `prefix_partial_path_with_controller_namespace`-Feature - `Devise::SessionsController` ist ein
  *namespaced* Controller (Präfix `devise/sessions`), und ein implizites `render entries` versucht
  dann, das Namespace-Präfix in den Partial-Pfad einzumischen, ohne zu prüfen ob das Ergebnis
  überhaupt existiert. Fix: `render partial:`/`collection:` explizit statt implizit. Gleich noch
  den Player auf Devise-Seiten ganz ausgeblendet (`devise_controller?`) und die Login-Seite auf
  reinen "Login mit Spotify"-Button reduziert, da die App ohnehin nie Multiuser war.
* Intent 52 nachgeholt (war seit einer Weile liegen geblieben): `HelpController` von einer
  hardcoded Action auf eine `ARTICLES`-Whitelist umgebaut, drei neue Hilfeartikel (Installation,
  Bedienung, Diary) ergänzt. Kleiner Folgefehler dabei selbst verursacht und gleich behoben: jede
  Markdown-Datei bringt ihre `# Titel`-Überschrift schon selbst mit, die View setzte zusätzlich ein
  eigenes `<h1>` davor - jeder Artikel zeigte den Titel doppelt.
* Intent 55: gleich vier Bugs in der Tracks-Suche-Autocomplete auf einmal behoben (Kategorie-Filter
  wurde bei Vorschlägen ignoriert, Dropdown nicht scrollbar, ein schon in der Komma-Liste stehender
  Wert wurde nochmals vorgeschlagen, Übernehmen eines Vorschlags hängte ein störendes Leerzeichen
  an, das Komma-Listen-Weitertippen kaputt machte).
* Intent 56: ein einmaliger, nicht reproduzierbarer Aussetzer (beide Audio-Kanäle verstummten bei
  einem Seitenwechsel) mit reinem Diagnose-Logging angegangen, statt blind zu raten. Ergebnis schon
  beim ersten Test aufschlussreich: Haupt- und Cue-Player-Controller disconnecten/reconnecten bei
  *jeder* Navigation (bekannte Turbo-Permanent-Eigenheit), normalerweise ohne die Wiedergabe zu
  stören - der Verdacht verschiebt sich auf ein selteneres Versagen der Permanent-Element-Übernahme
  in genau diesem Fenster. Funde/Lösungsideen dafür in neuer `.intents/Ideen.md` festgehalten, statt
  sie ungeprüft gleich umzusetzen.
* Lehrreicher Fehler (zweimal an verschiedenen Stellen passiert): ein Request-Spec-Test, der nur
  auf Textfragmente im Response-Body prüfte, wurde von einer 500er-Rails-Debug-Fehlerseite zufällig
  "grün" bestätigt, weil die Fehlerseite die gesuchten Wörter (z.B. Werte aus einem SQL-Insert-Log)
  selbst enthielt. Seitdem in neuen Tests konsequent zuerst den HTTP-Status explizit geprüft, bevor
  auf Body-Inhalt geprüft wird.

## 2026-07-04
* Rate-Limit-Fix zuerst: `release_date`/`popularity` bei Alben und Artists waren durchgehend
  leer, weil bei einem vollen Sync über viele Playlists praktisch jeder Alben-/Artists-Batch
  mit 429 (Rate Limit) fehlschlug (Requests liefen ohne Pause aufeinanderfolge). Fix:
  `SpotifyPlaylistsGateway#fetch_in_slices` retryt 429 jetzt mit Backoff (`Retry-After`-Header
  falls vorhanden, sonst exponentiell, max. 3 Versuche); dazu ein Backfill-Rake-Task
  (`backfill_album_and_artist_details`) für die schon betroffenen Alben/Artists.
* Spotifys `audio-features`-Endpoint (Tempo/Energy) ist für diese App dauerhaft gesperrt (seit
  27.11.2024, Extended Quota Mode seit Mai 2025 nur noch für Businesses mit ≥250'000 MAU
  erreichbar) - kein Workaround möglich.
* Nebenbefund dabei: in der DB stand bei **allen** Tracks der Literalwert `"null"` in
  `audio_features` statt echten Daten - ein Doppel-Encoding-Bug (`nil.to_json` auf eine
  bereits als `t.json` typisierte Spalte geschrieben). Es gab also nie echte Audio-Features,
  die verloren gehen könnten.
* Lösung: Intent 35 - Tempo/Energy werden jetzt lokal aus den heruntergeladenen Dateien via
  [Essentia](https://essentia.upf.edu/) berechnet, direkt nach dem Download (siehe
  `AudioFeaturesExtractor`/`AudioFeaturesExtractionService`).
* Erster Versuch: Essentia via Homebrew-Tap `MTG/essentia` (`brew install essentia --HEAD`)
  installieren. Kompiliert auf Apple Silicon nicht (`waf configure` bricht ab) - bekanntes,
  offenes Problem dieses Taps (mehrere Issues in MTG/homebrew-essentia dazu), kein
  Einzelfall.
* Lösung dafür: Essentia läuft stattdessen im fertigen Docker-Image
  `ghcr.io/mgoltzsche/essentia` (multi-arch, läuft nativ auf Apple Silicon, kein Kompilieren
  nötig). Als Nebeneffekt sogar einfacherer Code: Output kommt als JSON direkt auf stdout
  (`-` als Output-Pfad), keine temporäre Datei nötig.
* Homebrew hat dabei übrigens eine neue Hürde eingebaut: seit Version 6.0 (Juni 2026) müssen
  Drittanbieter-Taps explizit "getrusted" werden (`brew trust --formula ...`), bevor sie
  überhaupt geladen werden - Reaktion auf einen Supply-Chain-Angriff auf einen anderen Tap im
  März 2026.
* Docker Desktop lokal installiert (`brew install --cask docker` - beim ersten Versuch im
  Hintergrund gescheitert, weil die Installation ein Terminal für die sudo-Passwortabfrage
  braucht; im normalen Terminal ausgeführt hat's dann geklappt) und end-to-end getestet:
  `AudioFeaturesExtractor` gegen eine echte heruntergeladene Datei laufen lassen, Ergebnis
  stimmt mit einem direkten `docker run`-Testaufruf überein.
* Zeitschätzung für den vollen Backfill (`rake extract_missing_audio_features`) über die
  ganze bestehende Bibliothek: ~10s/Track (Docker-Container-Start-Overhead pro Aufruf) -> bei
  2466 Tracks ca. 6-7 Std. Darum vorerst nur ein paar Tracks von Hand getestet, der volle
  Backfill ist auf später verschoben.
* Nebenbei entdeckt: essentia_streaming_extractor_music liefert im JSON viel mehr als nur
  Tempo/Energy - u.a. `tonal.key_*` (Tonart/Dur-Moll, interessant fürs harmonische Mixen),
  `highlevel.danceability`/`mood_*`/`genre_rosamerica` (ML-Klassifikatoren). Aktuell nicht
  genutzt, evtl. später ein eigener Intent.

## 2026-07-03
* Grosser Performance-/Aufräum-Tag rund um die Index-Seiten: Tracks-Index und Artists-Index
  liefen wegen fehlender Preloads und Verzeichnis-Scans pro Zeile lahm (Intents 26-30) -
  Genre wird jetzt als Read-Through-Cache in der DB gehalten, Verzeichnis-Scans für
  Track-Pfade werden pro Request gebündelt, fehlende Soundfiles zeigen ein Badge statt
  stummem Player, Artists-Seiten laden gebündelt.
* Sync überspringt unveränderte Playlists komplett anhand der `snapshot_id` (Intent 31) -
  grosser Speedup für den normalen Sync.
* Batch-API-Aufrufe beim Erstimport eingeführt (Intent 33) - Audio-Features/Alben/Artists
  gebündelt statt einzeln pro Track angefragt (Grundlage für den Fix vom 04.07.).
* Grosses Feature: Tracks-Index mit Paginierung (Pagy), Sortierung (inkl. Energie/Tempo aus
  dem audio_features-JSON) und Volltextsuche (inkl. Playlist-Namen), dazu ein
  Tabellen-Redesign (Intent 34).
* Diverses Refactoring: `DownloadPlaylistCommandBuilder`, `SpotifyPlaylistsGateway` und
  `TrackFileLocator` als eigene Services extrahiert.

## 2026-07-02
* Feature: einzelne Playlist manuell aktualisieren (Intent 19) - `refresh_playlist` in
  `BuildMusicNetService`, Refresh-Button mit Diff-Panel auf der Playlist-Seite.
* Bugfix: der volle Sync holte pro Playlist nur die ersten 100 Tracks statt zu paginieren
  (Intent 20).
* Reihe von Performance-Enhancements: spotdl-Downloads laufen playlist-weise statt pro Track
  (Intent 21), N+1-Queries auf der Playlist-Seite beseitigt (Intent 22), Sync-Transaktionen/
  Parallelitäts-Schutz/Log-Pegel überarbeitet (Intent 23), Track-Anzahl im Playlist-Index
  gebündelt geladen (Intent 24).
* Paralleler-Download-Schutz für Intent 25 geplant.

## 2026-07-01
* Migrations-Tag: Ruby- und Rails-Version sowie diverse Gems schrittweise angehoben (Intents
  12-18, Phase A-E: Ruby/Dev-Tooling, Devise 4→5, omniauth-spotify, Rails 7.1→8.1.3,
  verbleibende Gems).
* Altlasten aufgeräumt: ungenutztes Api::V1-Namespace samt `ApiToken` komplett entfernt.
* Testsuite massiv ausgebaut: Model-, Service- und Controller-Specs für so ziemlich die
  ganze App neu geschrieben (Album/Artist/Track/PlaylistTrack, BuildMusicNetService,
  Download-Services, Playlist/User-Model, alle Controller).
* Ein paar Bugfixes nebenbei: `Dir.chdir`-Thread-Safety-Problem beseitigt, Logout-Link auf
  `data-turbo-method` umgestellt, `spotify_user_data` wird jetzt bei jedem Login aktualisiert
  statt nur beim Erstellen.
* CLAUDE.md und CODE_GUIDELINES neu angelegt, bestehende Features rückwirkend als Intents
  dokumentiert (IDD-Workflow für den Rest des Projekts etabliert).

## 2025-12-04
* die Callback Adresse auf Spotify (und darum auch die Adresse, auf dem diese App läuft, geändert):
* 127.0.0.1 (Die Callbackadresse muss eine Loopbackadresse oder secure sein)
## 2023-10-08
* Heruntergeladene Files können nun abgespielt werden
* Informationen (Genre) aus den Tracks werden dargestellt. Mit hilfe des gems Wahwah

## 2023-10-02
V2 der API mit [graphiti](https://www.graphiti.dev/) erstellt. Ist eine Implementation der [json:api](https://jsonapi.org/) Spez.
Vandal läuft unter [api/v2/vandal](http://0.0.0.0:3001/api/v2/vandal). Das schema.json mit dem ganzen Beschriebe der Dokumentation wird ins public/api/v2/schemal.json generiert. (Wenn man die Tests laufen lässt)

Habe dann [graphiti-openapi](https://github.com/alsemyonov/graphiti-openapi) ausprobiert. Sollte aus dem graphiti schema.json dann OpenApi Doc erstellen. Ging aber nicht, darum wieder deinstalliert.

Interessant wäre als Alternative zu graphiti [jsonapi-rb](https://jsonapi-rb.org/)
## 2023-09-29
Rspec Tests der API. Diese dann swaggerized: `rake rswag:specs:swaggerize`
Die Swagger Dokumentation ist dann [api-docs/index.html](http://0.0.0.0:3001/api-docs/index.html)
Siehe 
- [rswag](https://github.com/rswag/rswag#rswag)
- [tutorial](https://blog.corsego.com/learn-openapi-swagger-rswag)

[Problem] Wenn ich das Spec für eine API aufrufen möchte ohne authorisierung (Diese habe ich ausgschaltet), funktioniert das zwar "blutt",
aber nicht wenn das Spec mit swagger annotiert ist. Es kommt: `Response body: {"error":"You need to sign in or sign up before continuing."}`
Siehe [spec](../spec/requests/api/v1/playlists_spec.rb)
-> Lösung: Falscher Pfad korrigiert :(

## 2023-09-28
API begonnen, nach [dieser Anleitung](https://blog.corsego.com/rails-api-bearer-authentication)
- Erster Endpoint mit Dummy Response `api/v1/home/index.json`
- Dann die Authentisierung durch ein Bearer Token
  - Schwierigkeiten. 
    - Zuerst ein [key_derivation_salt generieren](https://guides.rubyonrails.org/active_record_encryption.html)
    - und in die [credentials.yml.enc](../config/credentials.yml.enc) schreiben
      - Mit dem Befehl `EDITOR="vi" bin/rails credentials:edit` öffnen und die generierten credentials reinkopieren.
      - Das Gleiche noch für development Env: `EDITOR="vi" bin/rails credentials:edit --environment development`
    - Das token für den einen User in der Rails console generieren:
```
current_user = User.first
token = current_user.api_tokens.create!
```
- Nun kann ich das JSON so abfragen: `curl -X GET "http://0.0.0.0:3001/api/v1/home/index" -H "Authorization: Bearer mySecretToken"`
- Einen [Integrationstest geschrieben](../test/integration/api_welcome_page_test.rb)

- Dann die Dokumenation nach [dieser Anleitung](https://blog.corsego.com/learn-openapi-swagger-rswag)
 - Der Pfad des swagger.yaml ist im Unterschied zur Anleitung im public Ordner
 - Auf die Authentisierung im routes.rb habe ich verzichtet
 - Die erste Endpoint-Dok mit ChatGPT gemacht...

Mehr dazu [hier](api.md)