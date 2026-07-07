# frozen_string_literal: true

# Lädt release_date/popularity für Alben und popularity für Artists nach, die beim
# ursprünglichen Import leer blieben, weil der Alben-/Artists-Batch-Request wegen
# Rate-Limiting (429) fehlschlug (find_or_create_by! aktualisiert bestehende Zeilen sonst
# nie). Voraussetzung: SpotifyPlaylistsGateway#fetch_in_slices retryt 429 inzwischen mit
# Backoff, sonst würde dieser Task dieselben Fehler nur wiederholen.
desc 'lädt fehlende release_date/popularity für bestehende Alben und Artists nach'
task backfill_album_and_artist_details: [:environment] do
  gateway = SpotifyPlaylistsGateway.new(User.first)

  albums = Album.where(release_date: nil)
  puts "Alben ohne release_date: #{albums.count}"
  full_albums = gateway.albums_by_id(albums.pluck(:spotify_id))
  albums.find_each do |album|
    full_album = full_albums[album.spotify_id]
    next unless full_album

    album.update!(release_date: Album.normalize_release_date(full_album.release_date), popularity: full_album.popularity)
  end

  artists = Artist.where(popularity: nil)
  puts "Artists ohne popularity: #{artists.count}"
  full_artists = gateway.artists_by_id(artists.pluck(:spotify_id))
  artists.find_each do |artist|
    full_artist = full_artists[artist.spotify_id]
    next unless full_artist

    artist.update!(popularity: full_artist.popularity)
  end

  puts "Fertig. Weiterhin ohne release_date: #{Album.where(release_date: nil).count}, " \
       "weiterhin ohne popularity: #{Artist.where(popularity: nil).count}"
end
