# Diary
## 2026-07-09
* Bug: Rueckte ein Track ueber die Queue in den Player nach (statt per direktem Play-Button-Klick),
  fehlten zwei Dinge, die beim direkten Klick funktionieren: der Titel-Link im Player zeigte auf
  "#" statt die Track-Detailseite, und der Track wurde nicht in "Zuletzt gespielt" (lokale
  Playback-Historie, Intent 87) erfasst. Ursache: `QueueEntriesController#track_json` (liefert die
  Track-Infos an `/queue_entries/advance`) gab den Key `track_id` (snake_case) zurueck,
  `audio_player_controller.js#play` destrukturiert aber `{ url, name, trackId, artist }`
  (camelCase, wie es der direkte Play-Button-Weg schon immer lieferte) - `trackId` war beim
  Queue-Weg also immer `undefined`, wodurch sowohl der Link (`trackId ? ... : "#"`) als auch
  `persistPlayback(trackId)` (`if (!trackId) return`) stillschweigend ins Leere liefen. Fix: Key
  auf `trackId` umbenannt. Mit zwei neuen System-Specs abgesichert (Cuprite, da reine
  Request-Specs den JS-seitigen Key-Mismatch nie gesehen haetten) - gegen den alten Code als
  tatsaechlich rot verifiziert.
* Bug: `/artists/:id` warf einen 500er (`ActionView::MissingTemplate`, dann nach dem ersten Fix
  einen zweiten `NoMethodError`) - vom User live im Browser gemeldet. Ursache 1: `tracks/_tracks.erb`
  rendert die Track-Zeilen per `render partial: "track", collection: tracks, ...` mit einem
  unqualifizierten Partial-Namen - Rails loest den ueber die Prefixes des **aufrufenden
  Controllers** auf (nicht ueber das Verzeichnis der Partial selbst), bei `tracks#index` passte das
  zufaellig (Prefixes `["tracks", "application"]`), bei `artists#show` (Prefixes `["artists",
  "application"]`) nicht - "tracks/_track.erb" fehlte in der Suche. Fix: voll qualifizierter Pfad
  `"tracks/track"`. Ursache 2, danach sichtbar: `_track.erb` (ueber `_tag_cell.erb`/
  `_tag_assign_inline.erb`) braucht `@recent_tag_suggestions` (Intent 86), das `ArtistsController#show`
  nie gesetzt hat - nur `TracksController#index`/`#show` taten das. Fix: gleicher Aufruf auch in
  `ArtistsController#show` ergaenzt. Beide Fixes zusammen loesten nebenbei alle bisher als
  "vorbestehend, unabhaengig" eingestuften Failures in `artists_spec.rb` (11 Stueck) und sogar den
  scheinbar unabhaengigen `song_queue_spec.rb`-Failure auf - waren tatsaechlich alle derselbe Bug,
  keine getrennten Baustellen wie zuvor angenommen.
* Feature (Intent 88): Der Spotify-Tab in "Zuletzt gespielt" ist jetzt handlungsfähig statt reiner
  Text: bereits lokal vorhandene Tracks (Abgleich per `spotify_id`) verlinken direkt auf ihre
  Musicnet-Detailseite; noch nicht lokale Tracks lassen sich per Klick herunterladen -
  `ImportStandaloneSpotifyTrackService` legt Track/Album/Artist ohne Playlist-Zuordnung an,
  `DownloadStandaloneTrackService` lädt genau diesen einen Track per `spotdl` herunter (teilt sich
  den `DOWNLOAD_LOCK` mit dem bestehenden Playlist-Download), ein Hintergrund-Job kombiniert beides
  mit der Audio-Feature-Extraktion und meldet sich über denselben "downloads"-Kanal wie der
  bestehende Batch-Download. Nebenbei geklärt: die zuvor nur 12 sichtbaren Einträge waren keine
  Einschränkung dieser App, sondern Spotifys eigenes, rollierendes ~50-Wiedergaben-Fenster
  (`/me/player/recently-played` liefert nie mehr, auch nicht in der Spotify-App selbst) - der
  bestehende Aufruf fragte bereits das Maximum an. Ein kurzer Hinweistext im Spotify-Tab macht das
  jetzt nachvollziehbar.
* Bug (Nachtrag Intent 88, sofort beim ersten manuellen Test gefunden): der "Herunterladen"-Button
  im Spotify-Tab lud die Datei zwar korrekt herunter, aber ohne Rueckmeldung und ohne dass die
  Detailseite sie als "in DB gespeichert" erkannte. Ursache 1: `turbo_stream_from "downloads"` +
  der `#download-log`-Container existierten nur auf `/tracks`, nicht auf "Zuletzt gespielt", wo der
  Button liegt - der Broadcast kam an, aber niemand fing ihn auf. Ursache 2:
  `DownloadStandaloneTrackService` schrieb den ermittelten Dateinamen nie in die `file_name`-Spalte
  (anders als `DownloadResultParser#persist_file_name`, Intent 72). Beide Stellen ergaenzt,
  Regressionstests gegen den alten Stand verifiziert.
* Bug (Nachtrag Intent 88, zweiter manueller Test): beim naechsten Versuch schlug der eigentliche
  Datei-Download fehl (Track-Import/DB-Eintrag lief durch) - aber wieder ganz ohne Rueckmeldung,
  diesmal nicht mal eine Fehlermeldung. Ursache: `ImportAndDownloadSpotifyTrackJob` fing keine
  Exceptions aus dem Download-Schritt ab; der `:async`-ActiveJob-Adapter loggt eine unbehandelte
  Exception nur serverseitig, zeigt sie aber nirgends an - der Broadcast danach wurde schlicht nie
  erreicht. Fix: `safely_download` faengt jede Exception ab und broadcastet garantiert einen
  Fehlschlag, gleiches Soft-Failure-Prinzip wie bei `AudioFeaturesExtractor`/`LocationNameResolver`.
  Reproduziert und gegen den alten Stand als tatsaechlich rot verifiziert.
* Bug (Intent 87, Session-Kopfzeile): `pluralize(count, "Titel")` haengt ohne explizites
  `plural:`-Argument ein englisches "s" an ("5 Titels" statt "5 Titel") - im Deutschen ist "Titel"
  im Plural gleich dem Singular. Fix: `pluralize(count, "Titel", plural: "Titel")`.

* Bug: Lief gerade ein Track im globalen Player und man wies dem Track auf der Detailseite
  (`/tracks/:id`) manuell ein Tag zu (Intent 79), stoppte die Wiedergabe sofort. Ursache: das
  Zuweisungs-Formular hatte `data-turbo="false"` gesetzt (seit Intent 83 nötig, weil der
  Turbo-Stream aus `TrackTagsController#create` nur die Tags-Zelle der `/tracks`-Liste kannte und
  auf der Detailseite ein stiller No-Op gewesen wäre) - das deaktiviert aber nicht nur den
  Turbo-Stream, sondern Turbo Drive für den ganzen Submit, wodurch der Browser einen echten
  Hard-Reload der Seite auslöste. `data-turbo-permanent` (der globale Audio-Player) überlebt nur
  Turbo-Drive-Visits, keinen klassischen Reload - das Dokument inkl. `<audio>`-Element wurde
  komplett neu aufgebaut. Fix: eigene Partial `tracks/_tag_panel.html.erb` mit eigenem `dom_id`
  für den Tag-Bereich der Detailseite, der Turbo-Stream ersetzt jetzt beide Ziele (Listen-Zelle
  UND Detailseiten-Panel; ein `turbo_stream.replace` auf ein nicht vorhandenes Ziel ist ein
  stiller No-Op, daher gefahrlos immer beide zu rendern) - `data-turbo="false"` konnte ganz
  entfallen. Regressionsabgesichert in `spec/system/tag_assign_spec.rb` (gegen den alten Code
  reproduziert, mit dem Fix grün).

## 2026-07-08
* Feature (Intent 79): Tags lassen sich jetzt auch manuell auf der Track-Detailseite zuweisen -
  Livesuche nach einem bestehenden Tag (inkl. Kategorie), oder bei einem neuen Namen die Kategorie
  wählen, danach die Stärke - und wieder entfernen. Auf Wunsch komplett per Tastatur bedienbar
  (Pfeiltasten/Enter statt Klick in der Vorschlagsliste), inkl. "Zurück"-Möglichkeit, falls man
  beim zweiten Schritt merkt, das falsche Tag erwischt zu haben.
* Feature (Intent 80): Tabellenspalten auf `/tracks` und der Playlist-Detailseite sind jetzt pro
  User konfigurierbar (Einstellungen-Seite), statt fest. Auslöser war die Frage, ob die
  Playlists-Spalte nach Einführung der Tags (Intent 77) überhaupt noch nötig ist - Antwort war
  "ja, andere Funktion" (exakte Zugehörigkeit vs. verlustbehaftete Verdichtung), also gleich alle
  Spalten konfigurierbar statt nur diese eine.
* Zweimal am selben Tag einem Spring-Preloader-Fehlalarm hinterhergejagt: einmal ein
  OAuth-Login-Fehler nach einem Server-Neustart mitten im Login-Flow, dann eine Einstellung, die
  laut Erfolgsmeldung gespeichert wurde, aber sichtbar nichts bewirkte. Beide Male lag es an einem
  seit 35 Stunden laufenden Spring-Prozess, der den Code-Stand des laufenden `bin/rails server`
  eingefroren hatte - kein Bug in der App. Lehre fürs nächste Mal: bei unerklärlichem Verhalten
  zuerst `ps aux | grep spring` auf verdächtig alte Prozesse prüfen, bevor man in der App-Logik
  sucht.

## 2026-07-07
* Bug: `Album#release_date` (eine `date`-Spalte) verschluckte unvollständige Spotify-Angaben wie
  "1970" (nur Jahr, je nach `release_date_precision`) stillschweigend zu `nil` - ActiveRecord
  castet einen nicht vollständig parsbaren Datums-String ohne Fehler. Betraf sowohl den
  Backfill-Task als auch den regulären Sync. Fix: `Album.normalize_release_date` ergänzt fehlenden
  Monat/Tag (`"1970"` → `"1970-01-01"`).
* Die "Veröffentlichung"-Spalte auf dem Tracks-Index und der Playlist-Ansicht war seit dem
  Tabellen-Redesign verschwunden, obwohl das Backend (Sortierung, DSL-Suchfeld `year:`/`release:`)
  sie längst unterstützte - UI-seitig wieder ergänzt, sortierbar.
* Grosses Feature (Intent 77): Playlist-Namen wie "Blues mit Violine" oder "Fusion sad" stecken
  mehr Information als nur Genre - eine Analyse aller 247 Playlist-Namen ergab eine Taxonomie aus
  12 Kategorien mit ca. 142 Tags (Emotion, Instrumentierung, Musikstil, Geografie, Widmung, ...).
  Neues Datenmodell `Category` → `Tag` → `TrackTag` (mit `strength` 1-10, häufigkeitsbasiert), per
  Rake-Task `assign_track_tags` automatisch aus den Playlist-Namen befüllt (idempotent,
  wiederholbar nach Taxonomie-Änderungen), plus Verwaltungs-UI (`/categories`), `tag:`-Suchfeld und
  nach Kategorie gruppierte Anzeige.
* Reale Falle beim Bauen der Alias-Erkennung: reines Teilstring-Matching (wie bei `Library`) hätte
  den Alias "sad" fälschlich auch in "Salsadancers" gefunden - `Tag#matches_normalized_name?`
  braucht darum Wortgrenzen (`\b...\b`) statt `include?`, plus eine Normalisierung, die Bindestriche
  /Unterstriche zu Leerzeichen macht statt sie zu entfernen (sonst verschmilzt z.B. "rock'n'roll"
  zu einem Wort und verliert seine Wortgrenze).
* Nachtrag (Intent 78): ein im Playlist-Namen enthaltenes Auftrittsdatum (z.B.
  "2023-12-01_Salsadancers") wird jetzt ebenfalls als Tag erkannt, unter einer eigenen Kategorie
  "Auftrittsdatum" - bewusst nicht über das generische Alias-Matching, da ein kurzes Jahres-Tag
  ("2026") sonst fälschlich auch in einem präziseren Datum ("2026-01-05...") mitgematcht hätte.

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