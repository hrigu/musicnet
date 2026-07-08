# frozen_string_literal: true

class RelatedTracksFinder
  # Kapselt die vier nicht-tag-basierten Attribute (Genre, Bibliothek, Energie, Tempo, Intent 84
  # Nachtrag 5) - eigene Klasse, damit RelatedTracksFinder selbst nicht zu gross wird. Tags bleiben
  # dort, da sie eng mit category_ids/base_track_tags verzahnt sind.
  class AttributeMatcher
    MAX_POINTS = RelatedTracksFinder::MAX_STRENGTH_DIFFERENCE
    ENERGY_DIFFERENCE_DIVISOR = 10.0
    TEMPO_DIFFERENCE_DIVISOR = 5.0
    KEYS = %i[genre library energy tempo].freeze

    def initialize(track, weights)
      @track = track
      @weights = weights
    end

    def enabled?(key)
      @weights.key?(key)
    end

    # Fuer active_comparison_count - wie viele der aktivierten Attribute hat der Ausgangstrack
    # ueberhaupt selbst als Wert, kann also fuer den Vergleich etwas beitragen.
    def active_origin_value_count
      KEYS.count { |key| enabled?(key) && origin_value(key).present? }
    end

    def candidate_ids
      ids = Set.new
      ids.merge(genre_candidate_ids) if enabled?(:genre) && origin_value(:genre).present?
      ids.merge(library_candidate_ids) if enabled?(:library) && origin_library_ids.any?
      ids.merge(numeric_candidate_ids) if numeric_active?
      ids
    end

    def contributions_for(candidate)
      [
        genre_contribution(candidate),
        library_contribution(candidate),
        energy_contribution(candidate),
        tempo_contribution(candidate)
      ].compact
    end

    private

    def origin_value(key)
      case key
      when :genre then @track.genre
      when :library then origin_library_ids.presence
      when :energy then @track.energy
      when :tempo then @track.tempo
      end
    end

    # Bewusst eine eigenstaendige Query statt @track.playlists.flat_map(&:library_ids) - der
    # Ausgangstrack kommt aus TracksController#show via Track.for_show, das :playlists nie
    # vorlaedt und strict_loading aktiviert (dokumentierte Falle, siehe CLAUDE.md); ein Zugriff auf
    # diese Assoziation wuerde einen ActiveRecord::StrictLoadingViolationError ausloesen (real
    # aufgetreten, Intent 84 Nachtrag 5 Bugfix).
    def origin_library_ids
      @origin_library_ids ||= Library.joins(playlists: :playlist_tracks)
                                     .where(playlist_tracks: { track_id: @track.id })
                                     .distinct
                                     .pluck(:id)
    end

    def genre_candidate_ids
      Track.where(genre: @track.genre).where.not(id: @track.id).pluck(:id)
    end

    def library_candidate_ids
      Track.joins(playlists: :libraries)
           .where(libraries: { id: origin_library_ids })
           .where.not(id: @track.id)
           .distinct
           .pluck(:id)
    end

    def numeric_active?
      (enabled?(:energy) && @track.energy) || (enabled?(:tempo) && @track.tempo)
    end

    def numeric_candidate_ids
      Track.where.not(audio_features: nil).where.not(id: @track.id).pluck(:id)
    end

    def genre_contribution(candidate)
      return nil unless enabled?(:genre)

      origin_genre = @track.genre
      candidate_genre = candidate[:genre]
      return nil if origin_genre.blank? || candidate_genre.blank?
      return nil unless origin_genre.casecmp?(candidate_genre)

      Contribution.new("Genre", origin_genre, candidate_genre, MAX_POINTS, @weights[:genre])
    end

    def library_contribution(candidate)
      return nil unless enabled?(:library)

      shared_ids = origin_library_ids & candidate.playlists.flat_map(&:library_ids).uniq
      return nil if shared_ids.empty?

      names = Library.where(id: shared_ids).order(:name).pluck(:name).join(", ")
      Contribution.new("Bibliothek", names, names, MAX_POINTS, @weights[:library])
    end

    def energy_contribution(candidate)
      return nil unless enabled?(:energy)

      base = @track.energy
      candidate_value = candidate.energy
      return nil if base.nil? || candidate_value.nil?

      numeric_contribution("Energie", (base * 100).round, (candidate_value * 100).round,
                           ENERGY_DIFFERENCE_DIVISOR, @weights[:energy])
    end

    def tempo_contribution(candidate)
      return nil unless enabled?(:tempo)

      base = @track.tempo
      candidate_value = candidate.tempo
      return nil if base.nil? || candidate_value.nil?

      numeric_contribution("Tempo", base.round, candidate_value.round, TEMPO_DIFFERENCE_DIVISOR, @weights[:tempo])
    end

    def numeric_contribution(label, base_value, candidate_value, divisor, weight)
      points = [MAX_POINTS - ((candidate_value - base_value).abs / divisor), 0].max.round(2)
      return nil if points.zero?

      Contribution.new(label, base_value, candidate_value, points, weight)
    end
  end
end
