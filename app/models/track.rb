# frozen_string_literal: true

require "ostruct"

class Track < ApplicationRecord
  belongs_to :album
  has_and_belongs_to_many :artists
  has_many :playlist_tracks
  has_many :queue_entries, dependent: :destroy

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
    "energy" => "json_extract(tracks.audio_features, '$.energy')",
    "tempo" => "json_extract(tracks.audio_features, '$.tempo')"
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

  # Feld-Whitelist der DSL-Suche (Intent 43) — ordnet feld:wert-Tokens dem passenden
  # Scope zu. bpm/tempo und year/release sind bewusste Alias-Paare.
  FIELD_SCOPES = {
    "artist" => :by_artist,
    "album" => :by_album,
    "genre" => :by_genre,
    "playlist" => :by_playlist,
    "bpm" => :by_tempo,
    "tempo" => :by_tempo,
    "energy" => :by_energy,
    "popularity" => :by_popularity,
    "year" => :by_release_year,
    "release" => :by_release_year
  }.freeze
  NUMERIC_FIELDS = %w[bpm tempo energy popularity year release].freeze
  TEXT_FIELDS = %w[artist album genre playlist].freeze
  NUMERIC_VALUE = /\A-?\d+(\.\d+)?\z/

  # Übersetzt einen DSL-Suchstring (TrackQueryParser) in eine Track-Relation. Jeder
  # feld:wert-Token wird über eine Subquery angewendet (relation.where(id: ...)) statt über
  # einen direkten Join auf der Hauptrelation — nur so ergibt ein wiederholtes Feld
  # (z.B. zwei playlist:-Tokens) eine echte Schnittmenge statt eines nie erfüllbaren
  # Joins gegen dieselbe Zeile (siehe by_artist/by_playlist). Unbekannte Felder und
  # ungültige Werte für ein bekanntes Feld werden ignoriert bzw. als Freitext behandelt,
  # nie ein Fehler (Intent 43).
  #
  # ODER (Intent 47): der Token-Strom wird an :or-Tokens in UND-Gruppen aufgeteilt (OR bindet
  # schwächer als das Leerzeichen-UND, wie bei Mixxx). Jede Gruppe wird wie bisher ausgewertet,
  # aber als `where(id: gruppe.select(:id))` erneut in eine frische, unveränderte Relation
  # gewrappt, bevor die Gruppen per `Relation#or` vereinigt werden — nötig, weil `Relation#or`
  # strukturell identische Relationen verlangt (gleiche Joins/`distinct`), einzelne Gruppen aber
  # unterschiedliche Joins haben können (z.B. nur eine Gruppe mit Freitext, die intern
  # `Track.search`s left_joins nutzt). Leere Gruppen (führendes/abschliessendes/doppeltes OR)
  # werden ignoriert, kein Fehler.
  def self.search_query(query)
    return all if query.blank?

    groups = group_tokens_by_or(TrackQueryParser.new(query, known_fields: FIELD_SCOPES.keys).tokenize)
    return all if groups.empty?

    groups.map { |group| where(id: evaluate_and_group(group).select(:id)) }.reduce { |a, b| a.or(b) }
  end

  def self.group_tokens_by_or(tokens)
    groups = [[]]
    tokens.each do |token|
      token.type == :or ? groups.push([]) : groups.last.push(token)
    end
    groups.reject(&:empty?)
  end
  private_class_method :group_tokens_by_or

  def self.evaluate_and_group(tokens)
    relation = all
    free_text_terms = []

    tokens.each do |token|
      if token.type == :free_text
        free_text_terms << token.value
        next
      end

      scope_name = FIELD_SCOPES[token.field]
      unless scope_name
        free_text_terms << "#{token.field}:#{token.value}"
        next
      end

      match = TrackQueryParser.classify_value(token.value)
      next unless valid_match_for_field?(token.field, match)

      matching_ids = public_send(scope_name, match).select(:id)
      relation = token.negate ? relation.where.not(id: matching_ids) : relation.where(id: matching_ids)
    end

    free_text_terms.any? ? relation.search(free_text_terms.join(" ")) : relation
  end
  private_class_method :evaluate_and_group

  def self.valid_match_for_field?(field, match)
    return numeric_match_valid?(match) if NUMERIC_FIELDS.include?(field)
    return %i[contains list].include?(match[:type]) if TEXT_FIELDS.include?(field)

    false
  end
  private_class_method :valid_match_for_field?

  def self.numeric_match_valid?(match)
    case match[:type]
    when :list then match[:values].all? { |v| NUMERIC_VALUE.match?(v) }
    when :range then [match[:min], match[:max]].compact.all? { |v| NUMERIC_VALUE.match?(v) }
    when :comparison then NUMERIC_VALUE.match?(match[:value])
    when :contains then NUMERIC_VALUE.match?(match[:value])
    else false
    end
  end
  private_class_method :numeric_match_valid?

  def self.by_genre(match)
    where(text_match_condition("tracks.genre", match))
  end

  def self.by_album(match)
    joins(:album).where(text_match_condition("albums.name", match))
  end

  # Baut eine LOWER(spalte) LIKE ?-Bedingung, ODER-verknüpft bei mehreren Werten (match[:type]
  # == :list). Wird von allen Text-Feldern der DSL-Suche (Intent 43) geteilt.
  def self.text_match_condition(column, match)
    values = match[:type] == :list ? match[:values] : [match[:value]]
    sql = values.map { "LOWER(#{column}) LIKE ?" }.join(" OR ")
    [sql, *values.map { |value| "%#{value.downcase}%" }]
  end
  private_class_method :text_match_condition

  # Subquery statt direktem joins(:artists).where(...): ein Track kann mehrere Künstler
  # haben, zwei verschiedene by_artist-Aufrufe müssen sich daher unabhängig voneinander
  # gegen die gejointe Zeile auswerten lassen — sonst könnte ein einzelner Join niemals
  # zwei unterschiedliche Künstlernamen gleichzeitig erfüllen (Intent 43).
  def self.by_artist(match)
    where(id: joins(:artists).where(text_match_condition("artists.name", match)).select(:id))
  end

  # Gleiches Subquery-Pattern wie by_artist — ermöglicht per Wiederholung (playlist:A
  # playlist:B) eine echte Schnittmenge statt einer Vereinigung (Intent 43).
  def self.by_playlist(match)
    where(id: joins(:playlists).where(text_match_condition("playlists.name", match)).select(:id))
  end

  # Reiner Anzeige-Filter (Intent 57, ersetzt in_active_category aus Intent 54), getrennt vom
  # Spotify-Sync - blank/nil bedeutet "Alle" (kein Filter). Gleiches Subquery-Pattern wie
  # by_playlist, aus demselben Grund (Join-Fanout/Kombinierbarkeit mit anderen Bedingungen der
  # bereits laufenden Suche).
  def self.in_active_library(library_id)
    return all if library_id.blank?

    where(id: joins(playlists: :libraries).where(libraries: { id: library_id }).select(:id))
  end

  def self.by_tempo(match)
    where(numeric_match_condition("json_extract(tracks.audio_features, '$.tempo')", match))
  end

  def self.by_energy(match)
    where(numeric_match_condition("json_extract(tracks.audio_features, '$.energy')", match))
  end

  def self.by_popularity(match)
    where(numeric_match_condition("tracks.popularity", match))
  end

  # release_date ist ein Datum, die DSL erlaubt aber nur ein Jahr (year:2015) — Vergleich
  # daher auf dem per strftime extrahierten Jahr statt auf dem Datum selbst.
  def self.by_release_year(match)
    joins(:album).where(numeric_match_condition("CAST(strftime('%Y', albums.release_date) AS INTEGER)", match))
  end

  ALLOWED_COMPARISON_OPERATORS = %w[> >= < <=].freeze

  # Baut eine Zahlen-Bedingung (exakt, ODER-Liste, Range oder Vergleichsoperator) für eine
  # Spalte oder ein SQL-Ausdruck (z.B. json_extract). Ungültige numerische Werte werden hier
  # bewusst nicht abgefangen — das erledigt der Aufrufer in Track.search_query (Intent 43,
  # Task 3), damit dieser Baustein einfach bleibt.
  def self.numeric_match_condition(column, match)
    case match[:type]
    when :list
      ["#{column} IN (?)", match[:values].map(&:to_f)]
    when :range
      numeric_range_condition(column, match[:min], match[:max])
    when :comparison
      return ["1=0"] unless ALLOWED_COMPARISON_OPERATORS.include?(match[:operator])

      ["#{column} #{match[:operator]} ?", match[:value].to_f]
    else
      ["#{column} = ?", match[:value].to_f]
    end
  end
  private_class_method :numeric_match_condition

  def self.numeric_range_condition(column, min, max)
    conditions = []
    values = []
    if min.present?
      conditions << "#{column} >= ?"
      values << min.to_f
    end
    if max.present?
      conditions << "#{column} <= ?"
      values << max.to_f
    end
    [conditions.join(" AND "), *values]
  end
  private_class_method :numeric_range_condition

  def self.for_show
    preload({ artists: :tracks }, { playlists: :libraries }, { album: [:artists] }).strict_loading
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
    @af ||= audio_features.present? ? OpenStruct.new(audio_features) : nil
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
