# frozen_string_literal: true

class TrackQueryParser
  Token = Struct.new(:type, :field, :value, :negate, keyword_init: true)

  # Token-Ebene (ganzer Query-String, Tokens durch Leerzeichen getrennt): ein Item ist ein
  # gequoteter Abschnitt oder ein ungequoteter Abschnitt ohne Komma/Leerzeichen - Leerzeichen
  # trennen hier noch ganze Tokens, duerfen also nicht Teil eines ungequoteten Items sein.
  TOKEN_ITEM = /"[^"]*"|[^,\s]+/
  # feld:item(,item)* als EIN Token - ohne das wiederholte (?:,TOKEN_ITEM)* würde ein
  # Tokenizer-Scan nach einem gequoteten Item direkt bei dessen schliessendem " abbrechen und ein
  # direkt anschliessendes ",weiteresItem" als eigenen, unsinnigen Freitext-Token uebrig lassen
  # (Bugfix, z.B. artist:"A.J. Croce",Kingfish).
  WORD_SCANNER = /-?[a-zA-Z_]+:#{TOKEN_ITEM}(?:,#{TOKEN_ITEM})*|"[^"]*"|\S+/
  FIELD_TOKEN = /\A(?<field>[a-zA-Z_]+):(?<value>.+)\z/

  COMPARISON = /\A(?<operator>>=|<=|>|<)(?<value>.+)\z/
  RANGE = /\A(?<min>[^.]*)\.\.(?<max>[^.]*)\z/

  # Werte-Ebene (innerhalb eines bereits isolierten Feld-Token-Werts): hier sind Leerzeichen
  # normaler Inhalt (z.B. ein ungequotetes "Fusion Abende SQ" als ein einzelnes Item), keine
  # Trennzeichen mehr - nur ein Komma trennt zwei Items.
  VALUE_ITEM = /"[^"]*"|[^,]+/

  def self.classify_value(value)
    return classify_range(value) if value.include?("..")
    return classify_comparison(value) if COMPARISON.match?(value)

    items = value.scan(VALUE_ITEM).map { |item| unquote(item) }
    return { type: :list, values: items } if items.size > 1

    { type: :contains, value: items.first }
  end

  # Nicht als private_class_method markiert - wird auch von der Instanzmethode #build_token
  # (Tokenisierung, nur fuer Freitext-Tokens) ueber self.class.unquote wiederverwendet. Bei
  # Feld-Tokens bleibt der Wert dagegen roh (siehe #build_token) - das Aufloesen von Anfuehrung
  # und Komma-Listen passiert einheitlich erst hier in classify_value.
  def self.unquote(value)
    value.start_with?('"') && value.end_with?('"') ? value[1..-2] : value
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

  # Ein Roh-Wort, das genau "feld:" oder "-feld:" ist (bekanntes Feld, noch kein Wert) - wird
  # mit dem naechsten Roh-Wort zusammengefuehrt, wenn ein Leerzeichen nach dem Doppelpunkt
  # getippt wurde (Intent 48). Nur bei bekannten Feldern (known_fields), sonst wuerde z.B. ein
  # zufaelliger Doppelpunkt in einem Freitext ("Blues: The Story") faelschlich verschmolzen.
  DANGLING_FIELD = /\A-?[a-zA-Z_]+:\z/

  def initialize(query, known_fields: [])
    @query = query
    @known_fields = known_fields
  end

  def tokenize
    merge_dangling_field_prefixes(@query.to_s.scan(WORD_SCANNER)).map { |word| build_token(word) }
  end

  private

  def merge_dangling_field_prefixes(words)
    merged = []
    index = 0
    while index < words.length
      word = words[index]
      next_word = words[index + 1]
      if dangling_known_field?(word) && next_word
        merged << (word + next_word)
        index += 2
      else
        merged << word
        index += 1
      end
    end
    merged
  end

  def dangling_known_field?(word)
    return false unless DANGLING_FIELD.match?(word)

    field = word.delete_prefix("-").delete_suffix(":")
    @known_fields.include?(field)
  end

  # "OR" (Grossschreibung) als eigenstaendiges Wort ist der ODER-Operator (Intent 47) - nur wenn
  # es unquotiert und alleinstehend vorkommt. Ein kleingeschriebenes "or" oder ein gequotetes
  # "OR" (word waere dann '"OR"', nicht "OR") bleibt bewusst normaler Freitext/Feld-Wert.
  def build_token(word)
    return Token.new(type: :or, field: nil, value: nil, negate: false) if word == "OR"

    negate = word.start_with?("-")
    candidate = negate ? word[1..] : word
    match = FIELD_TOKEN.match(candidate)
    return Token.new(type: :free_text, field: nil, value: self.class.unquote(word), negate: false) unless match

    Token.new(type: :field, field: match[:field], value: match[:value], negate: negate)
  end
end
