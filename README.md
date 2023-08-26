# Musicnet
Holt Playlists, Tracks etc des eingeloggten Benutzers und kann die Tracks runterladen

## Spotify
### Spotify API: 
https://developer.spotify.com/documentation/web-api

### Spoty
Die Spotify App welche die Credentials enthält, damit diese Webpapp überhaupt auf die API zugreifen kann.
https://developer.spotify.com/dashboard/61f2f8a2eb7340e89e33723785125ca5
###
Die Client ID und Client Secret sind dort hinterlegt.

### Ruby Wrapper: rspotify
https://github.com/guilhermesad/rspotify


### Login 

# Architektur

## Tools
### spotdl
Ein Command-Line Tool welches Tracks runterlädt.
https://github.com/spotDL/spotify-downloader

In Python geschrieben.


## Tables
```
playlists <-->> playlist_tracks <<--> tracks <<---> albums
                                       ^
                                       |
                                       |
                                 artists_tracks (join table)
                                       |
                                       |
                                     artists    
users          
```

## Anderes

### Credentials
Die CLient-ID und Client-Secret von Spotify sind als Credentials in der RailsApp hinterlegt und eingebacken.
So hat man Zugriff: Rails.application.credentials.dig(:spotify, :client_id)

### Zugriff auf private Infos in Spotify
 * omniauth :spotify Strategie in Devise einbinden
 * 2023-08-26 Funktionierte nicht mehr: Fehlermeldung "omniauth: Attack prevented by OmniAuth::AuthenticityTokenProtection"
   * Lösung: gem omniauth-rails_csrf_protection einbinden.  