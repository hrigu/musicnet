# Liefert Autocomplete-Vorschläge für die DSL-Suche (Intent 43). Der übergebene Term ist der
# zuletzt/aktuell getippte Token (vom JS bereits am Leerzeichen abgeschnitten) — entweder ein
# Feldname-Präfix (kein Doppelpunkt) oder feld:teilwert.
class TrackQuerySuggestions
  MAX_SUGGESTIONS = 10

  VALUE_SOURCES = {
    "genre" => ->(prefix) { Track.distinct.where.not(genre: [nil, ""]).where("LOWER(genre) LIKE ?", "%#{prefix}%").order(:genre).limit(MAX_SUGGESTIONS).pluck(:genre) },
    "artist" => ->(prefix) { Artist.where("LOWER(name) LIKE ?", "%#{prefix}%").order(:name).limit(MAX_SUGGESTIONS).pluck(:name) },
    "album" => ->(prefix) { Album.where("LOWER(name) LIKE ?", "%#{prefix}%").order(:name).limit(MAX_SUGGESTIONS).pluck(:name) },
    "playlist" => ->(prefix) { Playlist.where("LOWER(name) LIKE ?", "%#{prefix}%").order(:name).limit(MAX_SUGGESTIONS).pluck(:name) }
  }.freeze

  def self.for(term)
    new(term).suggestions
  end

  def initialize(term)
    @term = term.to_s
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
    source = VALUE_SOURCES[field]
    return [] unless source

    source.call(prefix.downcase).map { |value| "#{field}:#{quote_if_needed(value)}" }
  end

  def quote_if_needed(value)
    value.include?(" ") ? "\"#{value}\"" : value
  end
end
