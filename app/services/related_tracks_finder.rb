# frozen_string_literal: true

# Verwandtschafts-Rangliste zu einem Ausgangs-Track (Intent 84). Metrik: pro vergleichbarem
# Attribut (gemeinsames Tag, Genre, Bibliothek, Energie, Tempo) ein Punktbeitrag, der bei
# numerischen Werten mit zunehmendem Unterschied sinkt und bei kategorischen Werten entweder voll
# oder gar nicht zaehlt, aufsummiert und mit einem optionalen Gewicht pro Attribut multipliziert.
# Diese Klasse ist bewusst nur noch der Orchestrator (Kandidaten sammeln, Beitraege einholen,
# diversifizieren, kuerzen) - die eigentliche Fachlogik pro Vergleichsart steckt in TagMatcher
# (Tags, immer aktiv, ueber category_ids einschraenkbar) und AttributeMatcher (Genre/Bibliothek/
# Energie/Tempo, einzeln ueber attribute_weights zu-/abschaltbar, Intent 84 Nachtrag 5 - nur ein
# Schluessel in diesem Hash gilt als aktiviert, der Wert ist das Gewicht).
class RelatedTracksFinder
  MAX_RESULTS = 10
  MAX_STRENGTH_DIFFERENCE = 10
  DEFAULT_ATTRIBUTE_WEIGHT = 1.0

  # Ein Eintrag pro vergleichbarem Attribut, der zur Gesamtpunktzahl eines Kandidat-Tracks
  # beigetragen hat - macht die Punktzahl in der View nachvollziehbar. label ist der Tag-Name bzw.
  # ein Attribut-Label ("Genre", "Tempo", ...), base_value/candidate_value die verglichenen Werte
  # (Staerken, Genre-Namen, BPM, ...).
  Contribution = Struct.new(:label, :base_value, :candidate_value, :points, :weight) do
    def weighted_points
      (points * weight).round(2)
    end
  end

  def initialize(track, category_ids: nil, attribute_weights: {})
    @track = track
    @tags = TagMatcher.new(track, Array(category_ids).map(&:to_i).presence)
    @attributes = AttributeMatcher.new(track, normalize_attribute_weights(attribute_weights))
  end

  def call
    results
  end

  # Anzahl der fuer die Berechnung tatsaechlich nutzbaren Vergleichspunkte (eigene Tags + aktivierte
  # Attribute, fuer die der Ausgangstrack einen Wert hat) - je weniger, desto weniger
  # aussagekraeftig ist die Rangliste, da nur wenige Attribute miteinander verglichen werden.
  def active_comparison_count
    @tags.base_tag_count + @attributes.active_origin_value_count
  end

  # Wie viele weitere Treffer mit exakt derselben Punktzahl wie der zuletzt angezeigte existieren,
  # aber wegen MAX_RESULTS nicht mehr angezeigt werden - macht sichtbar, dass die angezeigte
  # Auswahl bei einem Gleichstand willkuerlich ist, statt das stillschweigend zu verstecken. 0,
  # wenn gar nicht gekuerzt wurde.
  def additional_tied_count
    return 0 if results.size < MAX_RESULTS

    boundary_score = results.last[:score]
    total_at_boundary = @all_contributions.count { |_track_id, c| c.sum(&:weighted_points).round(2) == boundary_score }
    shown_at_boundary = results.count { |result| result[:score] == boundary_score }
    total_at_boundary - shown_at_boundary
  end

  private

  def results
    @results ||= compute_results
  end

  def compute_results
    candidate_ids = Set.new(@tags.candidate_ids).merge(@attributes.candidate_ids).delete(@track.id)
    return [] if candidate_ids.empty?

    candidates = tracks_by_id_for(candidate_ids)
    @all_contributions = build_all_contributions(candidates)
    return [] if @all_contributions.empty?

    diversify(@all_contributions)
      .first(MAX_RESULTS)
      .map { |track_id, contributions| build_result(candidates[track_id], contributions) }
  end

  def tracks_by_id_for(track_ids)
    Track.where(id: track_ids)
         .includes(:artists, track_tags: { tag: :category }, playlists: :libraries)
         .index_by(&:id)
  end

  # Ein Kandidat muss nicht in allen Quellen (Tag, Genre, Bibliothek, Energie/Tempo) auftauchen, es
  # reicht eine einzige - die vollstaendige Punktzahl wird hier ueber alle aktiven Vergleichsarten
  # gemeinsam berechnet, nicht nur ueber die Quelle, die ihn hat auftauchen lassen.
  def build_all_contributions(candidates)
    contributions_by_track_id = {}
    candidates.each_value do |candidate|
      contributions = @tags.contributions_for(candidate) + @attributes.contributions_for(candidate)
      contributions_by_track_id[candidate.id] = contributions if contributions.any?
    end
    contributions_by_track_id
  end

  # Ein haeufig vergebenes Tag (z.B. automatisch aus vielen Playlist-Namen zugeordnet) darf ein
  # selteneres, aber ebenso stark passendes Tag (z.B. nur manuell an wenige Tracks vergeben) nicht
  # aus der Rangliste verdraengen, nur weil beide auf die gleiche Punktzahl kommen und das
  # haeufigere Tag zufaellig mehr bzw. zuerst zurueckgegebene Kandidaten hat (Intent 84 Nachtrag).
  # Gruppiert daher zuerst nach dem staerksten beitragenden Attribut jedes Kandidaten, sortiert
  # jede Gruppe fuer sich nach gewichteter Punktzahl, und reiht die Gruppen dann abwechselnd
  # (Round-Robin) aneinander, bevor auf MAX_RESULTS gekuerzt wird.
  def diversify(contributions_by_track_id)
    buckets = contributions_by_track_id
              .sort_by { |_track_id, contributions| -contributions.sum(&:weighted_points) }
              .group_by { |_track_id, contributions| contributions.max_by(&:weighted_points).label }
              .values

    round_robin(buckets)
  end

  def round_robin(buckets)
    result = []
    buckets.each { |bucket| result << bucket.shift unless bucket.empty? } until buckets.all?(&:empty?)
    result
  end

  def build_result(track, contributions)
    { track: track, score: contributions.sum(&:weighted_points).round(2), contributions: contributions }
  end

  def normalize_attribute_weights(raw)
    raw.to_h.each_with_object({}) do |(key, weight), memo|
      key = key.to_sym
      next unless AttributeMatcher::KEYS.include?(key)

      memo[key] = weight.present? ? weight.to_f.clamp(0, Float::INFINITY) : DEFAULT_ATTRIBUTE_WEIGHT
    end
  end
end
