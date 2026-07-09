# frozen_string_literal: true

# Importiert einen einzelnen Spotify-Track als eigenstaendigen lokalen Track, ohne ihn einer
# Playlist zuzuordnen (Intent 88) - fuer Tracks aus dem Spotify-"Zuletzt gespielt"-Tab, die noch
# nicht lokal existieren. Angelehnt an BuildMusicNetService#build_track, aber bewusst ohne dessen
# Playlist-Kopplung und ohne die Batch-Prefetch-Optimierung (Intent 33): hier wird immer nur ein
# einzelner Track auf einmal importiert, der Mehraufwand einzelner Spotify-Requests fuer
# Album/Artist ist hier vernachlaessigbar.
class ImportStandaloneSpotifyTrackService
  def self.import(spotify_track_id)
    new(spotify_track_id).import
  end

  def initialize(spotify_track_id)
    @spotify_track_id = spotify_track_id
  end

  def import
    Track.find_by(spotify_id: @spotify_track_id) || build_track(RSpotify::Track.find(@spotify_track_id))
  end

  private

  def build_track(spot_track)
    Track.find_or_create_by!(spotify_id: spot_track.id) do |t|
      t.name = spot_track.name
      t.url = spot_track.external_urls["spotify"]
      t.duration_ms = spot_track.duration_ms
      t.popularity = try_fetch(spot_track, :popularity)
      t.album = build_album(spot_track.album)
      t.artists = build_artists(spot_track.artists)
    end
  end

  def build_album(spot_album)
    Album.find_or_create_by!(spotify_id: spot_album.id) do |a|
      a.name = spot_album.name
      a.release_date = Album.normalize_release_date(try_fetch(spot_album, :release_date))
      a.popularity = try_fetch(spot_album, :popularity)
      a.url = spot_album.external_urls["spotify"]
    end
  end

  def build_artists(spot_artists)
    spot_artists.map do |spot_artist|
      Artist.find_or_create_by!(spotify_id: spot_artist.id) do |a|
        a.name = spot_artist.name
        a.popularity = try_fetch(spot_artist, :popularity)
      end
    end
  end

  def try_fetch(object, attribute)
    object.send(attribute)
  rescue StandardError => e
    Rails.logger.debug(e.message)
    nil
  end
end
