# Diary
## 2026-07-04
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