# frozen_string_literal: true

class Track
  # Die DSL-Suchsprache hinter Track.search_query (Intent 43/45/47/48) - siehe
  # doc/track_search_syntax.md fuer die Syntax aus Nutzersicht. Ausgelagert aus Track selbst
  # (Intent-Architektur-Review), weil dieser Block allein rund die Haelfte der Klasse ausmachte;
  # reiner Umzug ohne Verhaltensaenderung. Konstanten liegen direkt im Modul (nicht in
  # class_methods), damit Track::FIELD_SCOPES ueber die normale Ancestor-Konstanten-Suche
  # funktioniert, sobald Track dieses Modul included.
  module Searchable
    extend ActiveSupport::Concern

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
      "release" => :by_release_year,
      "tag" => :by_tag
    }.freeze
    NUMERIC_FIELDS = %w[bpm tempo energy popularity year release].freeze
    TEXT_FIELDS = %w[artist album genre playlist tag].freeze
    NUMERIC_VALUE = /\A-?\d+(\.\d+)?\z/
    ALLOWED_COMPARISON_OPERATORS = %w[> >= < <=].freeze

    class_methods do
      # Volltextsuche über Name, Künstler, Album, Genre und Playlist-Name (Intent 34 + Nachtrag).
      # LEFT JOIN statt INNER, damit Tracks ohne Künstler/Playlist nicht aus dem Ergebnis fallen.
      # distinct gegen Duplikate durch die Artist-/Playlist-Join-Kardinalität (ein Track mit
      # mehreren Künstlern oder in mehreren Playlists hätte sonst mehrere Zeilen).
      def search(query)
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
      def search_query(query)
        return all if query.blank?

        groups = group_tokens_by_or(TrackQueryParser.new(query, known_fields: FIELD_SCOPES.keys).tokenize)
        return all if groups.empty?

        groups.map { |group| where(id: evaluate_and_group(group).select(:id)) }.reduce { |a, b| a.or(b) }
      end

      def by_genre(match)
        where(text_match_condition("tracks.genre", match))
      end

      def by_album(match)
        joins(:album).where(text_match_condition("albums.name", match))
      end

      # Subquery statt direktem joins(:artists).where(...): ein Track kann mehrere Künstler
      # haben, zwei verschiedene by_artist-Aufrufe müssen sich daher unabhängig voneinander
      # gegen die gejointe Zeile auswerten lassen — sonst könnte ein einzelner Join niemals
      # zwei unterschiedliche Künstlernamen gleichzeitig erfüllen (Intent 43).
      def by_artist(match)
        where(id: joins(:artists).where(text_match_condition("artists.name", match)).select(:id))
      end

      # Gleiches Subquery-Pattern wie by_artist — ermöglicht per Wiederholung (playlist:A
      # playlist:B) eine echte Schnittmenge statt einer Vereinigung (Intent 43).
      def by_playlist(match)
        where(id: joins(:playlists).where(text_match_condition("playlists.name", match)).select(:id))
      end

      # Gleiches Subquery-Pattern wie by_playlist - ermöglicht per Wiederholung (tag:sad
      # tag:tanzbar) eine echte Schnittmenge statt einer Vereinigung, da ein Track mehrere Tags
      # gleichzeitig haben kann.
      def by_tag(match)
        where(id: joins(:tags).where(text_match_condition("tags.name", match)).select(:id))
      end

      def by_tempo(match)
        where(numeric_match_condition("json_extract(tracks.audio_features, '$.tempo')", match))
      end

      # *100, da der rohe Essentia-Wert (0.0-1.0) skaliert wird, um auf derselben 0-100-Skala zu
      # vergleichen wie die Anzeige (engergie_to_view) - sonst matcht z.B. "energy:>5" nie und
      # "energy:0..30" matcht ausnahmslos jeden Track (Intent 70).
      def by_energy(match)
        where(numeric_match_condition("json_extract(tracks.audio_features, '$.energy') * 100", match))
      end

      def by_popularity(match)
        where(numeric_match_condition("tracks.popularity", match))
      end

      # release_date ist ein Datum, die DSL erlaubt aber nur ein Jahr (year:2015) — Vergleich
      # daher auf dem per strftime extrahierten Jahr statt auf dem Datum selbst.
      def by_release_year(match)
        joins(:album).where(numeric_match_condition("CAST(strftime('%Y', albums.release_date) AS INTEGER)", match))
      end

      private

      def group_tokens_by_or(tokens)
        groups = [[]]
        tokens.each do |token|
          token.type == :or ? groups.push([]) : groups.last.push(token)
        end
        groups.reject(&:empty?)
      end

      def evaluate_and_group(tokens)
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

      def valid_match_for_field?(field, match)
        return numeric_match_valid?(match) if NUMERIC_FIELDS.include?(field)
        return %i[contains list].include?(match[:type]) if TEXT_FIELDS.include?(field)

        false
      end

      def numeric_match_valid?(match)
        case match[:type]
        when :list then match[:values].all? { |v| NUMERIC_VALUE.match?(v) }
        when :range then [match[:min], match[:max]].compact.all? { |v| NUMERIC_VALUE.match?(v) }
        when :comparison then NUMERIC_VALUE.match?(match[:value])
        when :contains then NUMERIC_VALUE.match?(match[:value])
        else false
        end
      end

      # Baut eine LOWER(spalte) LIKE ?-Bedingung, ODER-verknüpft bei mehreren Werten (match[:type]
      # == :list). Wird von allen Text-Feldern der DSL-Suche (Intent 43) geteilt.
      def text_match_condition(column, match)
        values = match[:type] == :list ? match[:values] : [match[:value]]
        sql = values.map { "LOWER(#{column}) LIKE ?" }.join(" OR ")
        [sql, *values.map { |value| "%#{value.downcase}%" }]
      end

      # Baut eine Zahlen-Bedingung (exakt, ODER-Liste, Range oder Vergleichsoperator) für eine
      # Spalte oder ein SQL-Ausdruck (z.B. json_extract). Ungültige numerische Werte werden hier
      # bewusst nicht abgefangen — das erledigt der Aufrufer in Track.search_query (Intent 43,
      # Task 3), damit dieser Baustein einfach bleibt.
      def numeric_match_condition(column, match)
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

      def numeric_range_condition(column, min, max)
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
    end
  end
end
