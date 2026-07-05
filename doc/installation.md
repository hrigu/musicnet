# Installation

Diese Anleitung beschreibt, wie Musicnet auf einer (neuen) Maschine lauffähig gemacht wird.

## Voraussetzungen

* Ruby, Rails, sqlite3 (siehe `Gemfile`/`Gemfile.lock` für genaue Versionen)
* `bin/setup` ausführen (bundle install, `db:prepare`, Logs/Tmp leeren, Server-Neustart)

## Externe Tools

Musicnet ruft zwei externe Tools per Shell-Kommando auf — beide sind separat zu installieren,
keine Gems/Bundled Dependencies:

* **spotdl** ([spotdl](https://github.com/spotDL/spotify-downloader), Python-CLI) lädt die
  Audiodateien für Tracks herunter. Muss auf dem `PATH` verfügbar sein.
* **Essentia** berechnet Tempo/Energy lokal aus den heruntergeladenen Audiodateien. Läuft als
  Docker-Image `ghcr.io/mgoltzsche/essentia` — dafür muss Docker installiert und laufend sein
  (z.B. Docker Desktop: `open -a Docker`, dann 20-60s warten bis `docker info` keinen Fehler mehr
  liefert). Ohne laufendes Docker schlägt nur die Tempo/Energy-Extraktion pro Track fehl, der
  Download selbst gelingt trotzdem (Soft-Failure).

## Spotify-Credentials

Die `Client ID` und das `Client Secret` der mit dieser App verknüpften Spotify-App (Spotify
Dashboard) sind als Rails Encrypted Credentials hinterlegt, nicht als Umgebungsvariablen:
`Rails.application.credentials.dig(:spotify, :client_id)`. Sie werden beim Boot gelesen (siehe
`config/application.rb` und `config/initializers/devise.rb`).

### Setup auf einer neuen Maschine

Die verschlüsselten Dateien (`config/credentials.yml.enc`,
`config/credentials/development.yml.enc`) sind eingecheckt, die zugehörigen Schlüssel aber nicht.
Ohne sie liefert `credentials.dig(...)` nur `nil` und der Server bricht beim Boot mit
`RestClient::BadRequest (400 Bad Request)` aus `RSpotify.authenticate` ab.

Auf einer frischen Maschine müssen darum diese zwei Dateien von Hand hinterlegt werden (Quelle:
1Password bzw. eine bestehende Installation):

* `config/master.key`
* `config/credentials/development.key`

Beide bleiben dank `.gitignore` unversioniert. Alternative für `master.key`: Umgebungsvariable
`RAILS_MASTER_KEY` setzen (deckt aber `development.yml.enc` nicht ab). Zum Bearbeiten:
`EDITOR="vi" bin/rails credentials:edit` (mit `--environment development` für Dev-spezifische
Credentials). `config/master.key` niemals einchecken.

## Starten

```bash
bin/rails server -p 3001
```

Der Server **muss** auf `127.0.0.1:3001` laufen — die Spotify-OAuth-Callback-URL ist im Spotify
Dashboard exakt gegen diese Adresse registriert, ein anderer Port oder Host lässt den
Login-Redirect fehlschlagen.
