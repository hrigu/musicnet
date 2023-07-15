# README
* Rails 6.1
* gem 'bootstrap V5',
* gem 'rspotify'
* EDITOR="vi" bin/rails credentials:edit
* downgrade auf Ruby 2.6, da 3.0 mit rspotify nicht funktionerte
* devise

spotdl sync --save-file Africa.spotdl  --format m4a https://open.spotify.com/playlist/06nwKHMAuDIvjY4k15sSOi


Tables
playlists <-->> playlist_tracks <<--> tracks 
artists <-->> artists_tracks <<--> tracks
artists <-->> albums_artists <<--> albums
users               
