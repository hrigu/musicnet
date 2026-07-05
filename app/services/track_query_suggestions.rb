# Liefert Autocomplete-Vorschläge für die DSL-Suche (Intent 43). Der übergebene Term ist der
# zuletzt/aktuell getippte Token (vom JS bereits am Leerzeichen abgeschnitten) — entweder ein
# Feldname-Präfix (kein Doppelpunkt) oder feld:teilwert.
class TrackQuerySuggestions
  MAX_SUGGESTIONS = 10
  VALUE_SOURCE_FIELDS = %w[genre artist album playlist].freeze

  def self.for(term, category_substring = nil)
    new(term, category_substring).suggestions
  end

  def initialize(term, category_substring = nil)
    @term = term.to_s
    @category_substring = category_substring
  end

  def suggestions
    return [] if @term.blank?

    field, prefix = @term.split(":", 2)
    return field_name_suggestions(field) if prefix.nil?

    value_suggestions(field.downcase, prefix)
  end

  private

  def field_name_suggestions(prefix)
    Track::FIELD_SCOPES.keys.select { |name| name.start_with?(prefix.downcase) }.sort.map { |name| "#{name}:" }
  end

  def value_suggestions(field, prefix)
    return [] unless VALUE_SOURCE_FIELDS.include?(field)

    already_typed, current = split_last_item(prefix)
    values = send(:"#{field}_values", current.downcase)
    values.map { |value| "#{field}:#{already_typed}#{quote_if_needed(value)}" }
  end

  def genre_values(prefix)
    Track.in_active_category(@category_substring).distinct.where.not(genre: [nil, ""])
         .where("LOWER(genre) LIKE ?", "%#{prefix}%").order(:genre).limit(MAX_SUGGESTIONS).pluck(:genre)
  end

  def artist_values(prefix)
    Artist.in_active_category(@category_substring).where("LOWER(name) LIKE ?", "%#{prefix}%")
          .order(:name).limit(MAX_SUGGESTIONS).pluck(:name)
  end

  def album_values(prefix)
    Album.where("LOWER(name) LIKE ?", "%#{prefix}%").order(:name).limit(MAX_SUGGESTIONS).pluck(:name)
  end

  def playlist_values(prefix)
    Playlist.in_active_category(@category_substring).where("LOWER(name) LIKE ?", "%#{prefix}%")
            .order(:name).limit(MAX_SUGGESTIONS).pluck(:name)
  end

  # Nur das letzte, gerade getippte Komma-Item wird fuers Matching verwendet - vorherige Items
  # (already_typed) bleiben unveraendert als Praefix erhalten (Bugfix: "artist:hi,hu" durfte
  # nicht "hi,hu" als ganzes matchen, sondern nur "hu"). Ein fuehrendes " im aktuellen Item wird
  # entfernt, da der Nutzer mitten im Tippen eines gequoteten Werts ist (Bugfix: 'artist:"' durfte
  # nicht nach einem woertlichen Anfuehrungszeichen im Namen suchen).
  def split_last_item(prefix)
    comma_index = prefix.rindex(",")
    already_typed = comma_index ? prefix[0..comma_index] : ""
    current = comma_index ? prefix[(comma_index + 1)..] : prefix
    [already_typed, current.delete_prefix('"')]
  end

  def quote_if_needed(value)
    value.include?(" ") ? "\"#{value}\"" : value
  end
end
