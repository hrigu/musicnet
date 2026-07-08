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

  # Ein Eintrag pro gemeinsamem Tag, der zur Gesamtpunktzahl eines Kandidat-Tracks beigetragen hat
  # - macht die Punktzahl in der View nachvollziehbar (Intent 84 Nachtrag), statt nur die Summe
  # ohne Herkunft anzuzeigen.
  Contribution = Struct.new(:tag_name, :base_strength, :candidate_strength, :points)

  def initialize(track, category_ids: nil)
    @track = track
    @category_ids = Array(category_ids).map(&:to_i).presence
  end

  def call
    base_by_tag_id = base_track_tags.index_by(&:tag_id)
    return [] if base_by_tag_id.empty?

    contributions_by_track_id = group_contributions_by_track(base_by_tag_id)
    return [] if contributions_by_track_id.empty?

    tracks_by_id = tracks_by_id_for(contributions_by_track_id.keys)
    contributions_by_track_id
      .sort_by { |_track_id, contributions| -contributions.sum(&:points) }
      .first(MAX_RESULTS)
      .map { |track_id, contributions| build_result(tracks_by_id[track_id], contributions) }
  end

  private

  def base_track_tags
    scope = @track.track_tags
    scope = scope.joins(:tag).where(tags: { category_id: @category_ids }) if @category_ids
    scope.to_a
  end

  def tracks_by_id_for(track_ids)
    Track.where(id: track_ids).includes(:artists, track_tags: { tag: :category }).index_by(&:id)
  end

  def group_contributions_by_track(base_by_tag_id)
    contributions_by_track_id = Hash.new { |hash, key| hash[key] = [] }
    candidate_track_tags(base_by_tag_id.keys).includes(:tag).each do |candidate|
      contribution = build_contribution(base_by_tag_id[candidate.tag_id], candidate)
      contributions_by_track_id[candidate.track_id] << contribution if contribution
    end
    contributions_by_track_id
  end

  def build_contribution(base, candidate)
    points = [MAX_STRENGTH_DIFFERENCE - (candidate.strength - base.strength).abs, 0].max
    return nil if points.zero?

    Contribution.new(candidate.tag.name, base.strength, candidate.strength, points)
  end

  def candidate_track_tags(tag_ids)
    TrackTag.where(tag_id: tag_ids).where.not(track_id: @track.id)
  end

  def build_result(track, contributions)
    { track: track, score: contributions.sum(&:points), contributions: contributions }
  end
end
