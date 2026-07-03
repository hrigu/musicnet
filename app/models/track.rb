# frozen_string_literal: true

require "ostruct"

class Track < ApplicationRecord
  belongs_to :album
  has_and_belongs_to_many :artists
  has_many :playlist_tracks

  # Die Playlist die diesen Track enthlten
  has_many :playlists, through: :playlist_tracks

  def self.for_index
    preload(:artists, { playlist_tracks: :playlist }, :album).strict_loading
  end

  # Whitelist erlaubter Sortier-Spalten fuer den Tracks-Index (Intent 34) — verhindert, dass
  # roher User-Input in ein order() gelangt. release_date liegt auf Album, braucht daher einen
  # Join statt eines einfachen Spaltennamens.
  SORT_COLUMNS = {
    "name" => "tracks.name",
    "duration_ms" => "tracks.duration_ms",
    # Frühestes Datum, an dem der Track zu einer der Playlists hinzugefügt wurde, in denen er
    # heute noch vorkommt — nicht tracks.created_at, das nur den lokalen Import-Zeitpunkt zeigt.
    "added_at" => "(SELECT MIN(playlist_tracks.added_at) FROM playlist_tracks " \
                  "WHERE playlist_tracks.track_id = tracks.id)",
    "genre" => "tracks.genre",
    "popularity" => "tracks.popularity",
    "release_date" => "albums.release_date",
    # Ein Track kann mehrere Künstler haben (artists_tracks) — MIN(name) statt eines Joins,
    # damit kein Join-Fanout (Track mit 2 Künstlern würde sonst doppelt gezählt) entsteht.
    "artist" => "(SELECT MIN(artists.name) FROM artists_tracks " \
                "INNER JOIN artists ON artists.id = artists_tracks.artist_id " \
                "WHERE artists_tracks.track_id = tracks.id)",
    # audio_features wird immer per `.to_json` auf eine bereits-serialisierte Spalte
    # geschrieben (siehe BuildMusicNetService#build_track) und landet dadurch doppelt
    # JSON-kodiert in der DB (ein JSON-String, der selbst wieder JSON-Text enthaelt) - der
    # erste json_extract(..., '$') entfernt nur diese aeussere String-Verpackung.
    "energy" => "json_extract(json_extract(tracks.audio_features, '$'), '$.energy')",
    "tempo" => "json_extract(json_extract(tracks.audio_features, '$'), '$.tempo')"
  }.freeze
  DEFAULT_SORT_COLUMN = "name"

  def self.sorted(column, direction)
    column = SORT_COLUMNS.key?(column) ? column : DEFAULT_SORT_COLUMN
    direction = %w[asc desc].include?(direction) ? direction : "asc"

    relation = column == "release_date" ? joins(:album) : all
    relation.order(Arel.sql("#{SORT_COLUMNS[column]} #{direction}"))
  end

  # Volltextsuche über Name, Künstler, Album, Genre und Playlist-Name (Intent 34 + Nachtrag).
  # LEFT JOIN statt INNER, damit Tracks ohne Künstler/Playlist nicht aus dem Ergebnis fallen.
  # distinct gegen Duplikate durch die Artist-/Playlist-Join-Kardinalität (ein Track mit
  # mehreren Künstlern oder in mehreren Playlists hätte sonst mehrere Zeilen).
  def self.search(query)
    return all if query.blank?

    term = "%#{query.downcase}%"
    left_joins(:artists, :album, :playlists)
      .where(
        "LOWER(tracks.name) LIKE :term OR LOWER(artists.name) LIKE :term " \
        "OR LOWER(albums.name) LIKE :term OR LOWER(tracks.genre) LIKE :term " \
        "OR LOWER(playlists.name) LIKE :term",
        term: term
      )
      .distinct
  end

  def self.for_show
    preload({ artists: :tracks }, :playlists, { album: [:artists] }).strict_loading
  end

  def self.for_download
    tracks = preload(:playlists).strict_loading.to_a
    preload_track_paths(tracks)
    tracks
  end

  # Löst die Pfade aller Tracks mit einem einzigen Verzeichnis-Scan auf. Ohne Preload liest
  # track_path das Verzeichnis pro Track — bei tausenden Tracks dauert die Index-Seite
  # sonst zwanzig Sekunden statt zwei.
  def self.preload_track_paths(tracks)
    TrackFileLocator.preload_track_paths(tracks)
  end

  def dauer
    Time.at(duration_ms / 1000).utc.strftime('%M:%S')
  end

  # Frühestes Datum, an dem dieser Track zu einer seiner Playlists hinzugefügt wurde.
  # Nutzt die bereits preloadeten playlist_tracks (siehe .for_index), verursacht also
  # keine zusätzliche Query.
  def added_at
    playlist_tracks.map(&:added_at).min
  end

  # Siehe @RSpotify::Audiofeatures
  # - acousticness:     [Float] danceability Danceability describes how suitable a track is for dancing based on a combination of musical elements including tempo, rhythm stability, beat strength, and overall regularity. A value of 0.0 is least danceable and 1.0 is most danceable.
  # - mode:             Major, Minor (Oder 1 und 0)
  # - energy:           Float
  # - instrumentalness  Float
  # - liveness          Float
  # - loudness          Float
  # - speechiness       [Float] tempo The overall estimated tempo of a track in beats per minute (BPM). In musical terminology, tempo is the speed or pace of a given piece and derives directly from the average beat duration.
  # - time_signature    Integer
  # - valence           Float
  #
  # - duration_ms
  # - analysis_url
  # - key
  # - href
  # - id
  # - type
  # - uri
  def af
    @af ||= audio_features.present? ? JSON.parse(audio_features, object_class: OpenStruct) : nil
  end

  def energy
    af.try(:energy)
  end

  def tempo
    af.try(:tempo)
  end

  # Das Genre, wird aus dem runtergeladenen File gelesen und als Read-Through-Cache in der
  # DB abgelegt — es ändert sich praktisch nie, das Datei-Parsen kostet aber ~1.3s pro
  # Index-Aufruf. Invalidierung bewusst manuell via Track.update_all(genre: nil), siehe
  # Intent 28. update_column, weil es nur ein Cache ist (keine Callbacks, updated_at bleibt).
  def genre
    return self[:genre] if self[:genre].present?

    value = read_genre_from_file
    update_column(:genre, value) if value.present? && persisted?
    value
  end

  # @return den absoluten Pfad zum runtergeladenen Lied. Wird aus dem Namen des Tracks bestimmt.
  # Gewisse Zeichen werden im Pfad nicht oder anders verwendet, darum zuerst ersetzen.
  # Der Interpret ist meistens im Namen des Files auch vorhanden. Wird hier nicht berücksichtigt.
  # nil (Datei fehlt) ist ein gültiger Wert und wird mit-memoisiert, darum defined? statt ||=.
  def track_path
    return @track_path if defined?(@track_path)

    @track_path = TrackFileLocator.resolve_track_path(self)
  end

  private

  def read_genre_from_file
    return unless track_path

    WahWah.open(track_path).genre
  rescue WahWah::WahWahArgumentError, WahWah::WahWahNotImplementedError
    # Datei existiert, aber WahWah kann sie nicht parsen (z.B. unbekanntes Format).
    nil
  end

  # {"acousticness"=>0.552, "analysis_url"=>"https://api.spotify.com/v1/audio-analysis/2uSavRrWjouarU9DupcWmK", "danceability"=>0.69, "duration_ms"=>296333, "energy"=>0.553, "instrumentalness"=>0.914, "key"=>5, "liveness"=>0.121, "loudness"=>-12.152, "mode"=>1, "speechiness"=>0.0372, "tempo"=>131.674, "time_signature"=>4, "track_href"=>"https://api.spotify.com/v1/tracks/2uSavRrWjouarU9DupcWmK", "valence"=>0.917, "external_urls"=>nil, "href"=>nil, "id"=>"2uSavRrWjouarU9DupcWmK", "type"=>"audio_features", "uri"=>"spotify:track:2uSavRrWjouarU9DupcWmK"}
end
