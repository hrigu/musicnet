# frozen_string_literal: true

class RelatedTracksFinder
  # Kapselt den Tag-basierten Teil der Verwandtschafts-Berechnung (der urspruengliche Kern von
  # Intent 84, Stufe 1) - analog zu AttributeMatcher fuer Genre/Bibliothek/Energie/Tempo
  # ausgelagert, damit RelatedTracksFinder selbst als reiner Orchestrator klein bleibt.
  class TagMatcher
    def initialize(track, category_ids)
      @track = track
      @category_ids = category_ids
    end

    def base_tag_count
      base_track_tags.size
    end

    def candidate_ids
      return [] if base_track_tags.empty?

      TrackTag.where(tag_id: base_track_tags.map(&:tag_id)).where.not(track_id: @track.id).distinct.pluck(:track_id)
    end

    def contributions_for(candidate)
      return [] if base_track_tags.empty?

      candidate.track_tags.filter_map { |tt| contribution_for(tt) }
    end

    private

    def contribution_for(track_tag)
      base = base_by_tag_id[track_tag.tag_id]
      return nil if base.nil?

      points = [MAX_STRENGTH_DIFFERENCE - (track_tag.strength - base.strength).abs, 0].max
      return nil if points.zero?

      Contribution.new(track_tag.tag.name, base.strength, track_tag.strength, points, 1.0)
    end

    def base_by_tag_id
      @base_by_tag_id ||= base_track_tags.index_by(&:tag_id)
    end

    def base_track_tags
      @base_track_tags ||= begin
        scope = @track.track_tags
        scope = scope.joins(:tag).where(tags: { category_id: @category_ids }) if @category_ids
        scope.to_a
      end
    end
  end
end
