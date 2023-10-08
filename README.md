# Musicnet
Holt Playlists, Tracks etc des eingeloggten Benutzers und kann die Tracks runterladen

## Spotify
### Spotify API: 
https://developer.spotify.com/documentation/web-api

### Spoty
Die Spotify App welche mit dieser Anwendung verknüpft ist. Sie ist definiert im Spotify Dashboard und definiert
die Credentials, damit diese Webpapp überhaupt auf die API zugreifen kann. 
[spoty](https://developer.spotify.com/dashboard/61f2f8a2eb7340e89e33723785125ca5)

#### Credentials
Die `Client ID` und `Client Secret` sind dort hinterlegt.
Auf der Webpp: Siehe unter [Anderes/Credentials](#credentials-für-spotify-auf-der-webapp)

### Ruby Wrapper: rspotify
https://github.com/guilhermesad/rspotify

#### Authentication
Für viele SpotifyAPIS muss die Anwendung authentisiert sein. Diese Authentisierung findet beim Starten dieser App
statt. Siehe [application.rb](config/application.rb) und [Spotify Doc](https://developer.spotify.com/documentation/web-api/concepts/authorization)


### Login
Für das einloggen des Users mit oauth nehmen wir das gem `omniauth-spotify`. 
Siehe auch den [devise.rb](config/initializers/devise.rb) Initializer. Dort sind die scopes definiert, die freigeschalten sind.
Siehe [Spotify doc](https://developer.spotify.com/documentation/web-api/concepts/scopes) für Details über Scopes.

# Architektur

## Tools
### spotdl
[spotdl](https://github.com/spotDL/spotify-downloader) ist ein Command-Line Tool welches Tracks runterlädt.
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

### Credentials für Spotify auf der webapp
Die CLient-ID und Client-Secret von Spotify sind als Credentials in der RailsApp hinterlegt und eingebacken.
Dieser Key mit den Infos ist im config/master.key hinterlegt. Dieses nicht einchecken! Es muss geheim bleiben (1Password)
So hat man Zugriff: Rails.application.credentials.dig(:spotify, :client_id)

### Zugriff auf private Infos in Spotify
 * omniauth :spotify Strategie in Devise einbinden
 * 2023-08-26 Funktionierte nicht mehr: Fehlermeldung "omniauth: Attack prevented by OmniAuth::AuthenticityTokenProtection"
   * Lösung: gem omniauth-rails_csrf_protection einbinden.  

### Diary
[hier](doc/diary.md)