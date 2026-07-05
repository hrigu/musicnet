class TrackQueryParser
  Token = Struct.new(:type, :field, :value, :negate, keyword_init: true)

  WORD_SCANNER = /-?[a-zA-Z_]+:"[^"]*"|"[^"]*"|\S+/
  FIELD_TOKEN = /\A(?<field>[a-zA-Z_]+):(?<value>.+)\z/

  COMPARISON = /\A(?<operator>>=|<=|>|<)(?<value>.+)\z/
  RANGE = /\A(?<min>[^.]*)\.\.(?<max>[^.]*)\z/

  def self.classify_value(value)
    return classify_range(value) if value.include?("..")
    return classify_comparison(value) if COMPARISON.match?(value)
    return { type: :list, values: value.split(",") } if value.include?(",")

    { type: :contains, value: value }
  end

  def self.classify_range(value)
    match = RANGE.match(value)
    { type: :range, min: match[:min].presence, max: match[:max].presence }
  end
  private_class_method :classify_range

  def self.classify_comparison(value)
    match = COMPARISON.match(value)
    { type: :comparison, operator: match[:operator], value: match[:value] }
  end
  private_class_method :classify_comparison

  def initialize(query)
    @query = query
  end

  def tokenize
    @query.to_s.scan(WORD_SCANNER).map { |word| build_token(word) }
  end

  private

  def build_token(word)
    negate = word.start_with?("-")
    candidate = negate ? word[1..] : word
    match = FIELD_TOKEN.match(candidate)
    return Token.new(type: :free_text, field: nil, value: unquote(word), negate: false) unless match

    Token.new(type: :field, field: match[:field], value: unquote(match[:value]), negate: negate)
  end

  def unquote(value)
    value.start_with?('"') && value.end_with?('"') ? value[1..-2] : value
  end
end
