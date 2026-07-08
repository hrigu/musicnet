# frozen_string_literal: true

# Verwandtschafts-Rangliste zu einem Ausgangs-Track (Intent 84, Stufe 1 - bewusst ohne Karte/
# Layout, siehe .intents/completed/84.*.md). Metrik v1: pro gemeinsamem Tag ein Beitrag, der mit
# zunehmendem Staerke-Unterschied sinkt (10 - |Differenz|, nie negativ), aufsummiert ueber alle
# gemeinsamen Tags - zwei Tracks mit demselben Tag und aehnlicher Staerke gelten so als enger
# verwandt als mit weit auseinanderliegender Staerke. Absichtlich in Ruby statt einem SQL-Self-Join
# gehalten: bei der ueberschaubaren Tag-Anzahl dieses Single-User-Projekts ist das klar lesbar und
# schnell genug, ohne die Komplexitaet eines Self-Joins einzugehen.
class RelatedTracksFinder
  MAX_RESULTS = 10
  MAX_STRENGTH_DIFFERENCE = 10

  def initialize(track, category_ids: nil)
    @track = track
    @category_ids = Array(category_ids).map(&:to_i).presence
  end

  def call
    base_strength_by_tag_id = base_track_tags.index_by(&:tag_id).transform_values(&:strength)
    return [] if base_strength_by_tag_id.empty?

    scores = score_candidates(base_strength_by_tag_id)
    return [] if scores.empty?

    tracks_by_id = Track.where(id: scores.keys).index_by(&:id)
    scores.sort_by { |_track_id, score| -score }
          .first(MAX_RESULTS)
          .map { |track_id, score| { track: tracks_by_id[track_id], score: score } }
  end

  private

  def base_track_tags
    scope = @track.track_tags
    scope = scope.joins(:tag).where(tags: { category_id: @category_ids }) if @category_ids
    scope.to_a
  end

  def score_candidates(base_strength_by_tag_id)
    scores = Hash.new(0)
    candidate_track_tags(base_strength_by_tag_id.keys).each do |candidate|
      base_strength = base_strength_by_tag_id[candidate.tag_id]
      scores[candidate.track_id] += contribution(base_strength, candidate.strength)
    end
    scores
  end

  def candidate_track_tags(tag_ids)
    TrackTag.where(tag_id: tag_ids).where.not(track_id: @track.id)
  end

  def contribution(base_strength, candidate_strength)
    [MAX_STRENGTH_DIFFERENCE - (candidate_strength - base_strength).abs, 0].max
  end
end
