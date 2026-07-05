require "rails_helper"

RSpec.describe TrackQueryParser do
  describe "#tokenize" do
    it "zerlegt reinen Freitext in Freitext-Tokens" do
      tokens = described_class.new("miles davis").tokenize

      expect(tokens).to eq(
        [
          TrackQueryParser::Token.new(type: :free_text, value: "miles", field: nil, negate: false),
          TrackQueryParser::Token.new(type: :free_text, value: "davis", field: nil, negate: false)
        ]
      )
    end

    it "erkennt feld:wert-Tokens" do
      tokens = described_class.new("genre:jazz").tokenize

      expect(tokens).to eq(
        [TrackQueryParser::Token.new(type: :field, field: "genre", value: "jazz", negate: false)]
      )
    end

    it "erkennt ein Minus-Praefix als Negation" do
      tokens = described_class.new("-genre:blues").tokenize

      expect(tokens).to eq(
        [TrackQueryParser::Token.new(type: :field, field: "genre", value: "blues", negate: true)]
      )
    end

    it "behandelt einen in Anfuehrungszeichen gesetzten Wert als einen zusammenhaengenden Token" do
      tokens = described_class.new('playlist:"Fusion Abende" bpm:80').tokenize

      # Der Wert bleibt hier roh (inkl. Anfuehrungszeichen) - das Aufloesen passiert erst in
      # .classify_value, einheitlich fuer den Einzelwert- und den Listen-Fall (Bugfix, siehe unten).
      expect(tokens).to eq(
        [
          TrackQueryParser::Token.new(type: :field, field: "playlist", value: '"Fusion Abende"', negate: false),
          TrackQueryParser::Token.new(type: :field, field: "bpm", value: "80", negate: false)
        ]
      )
    end

    it "behandelt eine Komma-Liste mit gequotetem und ungequotetem Item als einen Token (Bugfix)" do
      tokens = described_class.new('artist:"A.J. Croce",Kingfish').tokenize

      expect(tokens).to eq(
        [TrackQueryParser::Token.new(type: :field, field: "artist", value: '"A.J. Croce",Kingfish', negate: false)]
      )
    end

    it "erkennt OR als eigenstaendigen Operator-Token (Intent 47)" do
      tokens = described_class.new("genre:pop OR genre:techno").tokenize

      expect(tokens).to eq(
        [
          TrackQueryParser::Token.new(type: :field, field: "genre", value: "pop", negate: false),
          TrackQueryParser::Token.new(type: :or, field: nil, value: nil, negate: false),
          TrackQueryParser::Token.new(type: :field, field: "genre", value: "techno", negate: false)
        ]
      )
    end

    it "behandelt ein kleingeschriebenes 'or' weiterhin als Freitext" do
      tokens = described_class.new("or").tokenize

      expect(tokens).to eq(
        [TrackQueryParser::Token.new(type: :free_text, field: nil, value: "or", negate: false)]
      )
    end

    it "behandelt OR innerhalb von Anfuehrungszeichen weiterhin als Teil des Werts" do
      tokens = described_class.new('artist:"Air OR Water"').tokenize

      expect(tokens).to eq(
        [TrackQueryParser::Token.new(type: :field, field: "artist", value: '"Air OR Water"', negate: false)]
      )
    end
  end

  describe "#tokenize mit known_fields (Intent 48)" do
    it "verschmilzt 'feld: wert' (Leerzeichen nach dem Doppelpunkt) bei bekanntem Feld" do
      tokens = described_class.new("artist: davis", known_fields: ["artist"]).tokenize

      expect(tokens).to eq(
        [TrackQueryParser::Token.new(type: :field, field: "artist", value: "davis", negate: false)]
      )
    end

    it "verschmilzt 'feld: \"gequotete Phrase\"' bei bekanntem Feld" do
      tokens = described_class.new('artist: "James Cotton"', known_fields: ["artist"]).tokenize

      expect(tokens).to eq(
        [TrackQueryParser::Token.new(type: :field, field: "artist", value: '"James Cotton"', negate: false)]
      )
    end

    it "verschmilzt auch mit Minus-Praefix (Negation)" do
      tokens = described_class.new("-artist: davis", known_fields: ["artist"]).tokenize

      expect(tokens).to eq(
        [TrackQueryParser::Token.new(type: :field, field: "artist", value: "davis", negate: true)]
      )
    end

    it "verschmilzt nicht bei unbekanntem Feld (bleibt Freitext, kein falsches Zusammenfuehren)" do
      tokens = described_class.new("blues: story", known_fields: ["artist"]).tokenize

      expect(tokens).to eq(
        [
          TrackQueryParser::Token.new(type: :free_text, field: nil, value: "blues:", negate: false),
          TrackQueryParser::Token.new(type: :free_text, field: nil, value: "story", negate: false)
        ]
      )
    end

    it "verschmilzt nicht ohne known_fields-Parameter (Rueckwaertskompatibilitaet)" do
      tokens = described_class.new("artist: davis").tokenize

      expect(tokens).to eq(
        [
          TrackQueryParser::Token.new(type: :free_text, field: nil, value: "artist:", negate: false),
          TrackQueryParser::Token.new(type: :free_text, field: nil, value: "davis", negate: false)
        ]
      )
    end

    it "laesst ein abschliessendes 'feld:' ohne folgendes Wort unveraendert" do
      tokens = described_class.new("artist:", known_fields: ["artist"]).tokenize

      expect(tokens).to eq(
        [TrackQueryParser::Token.new(type: :free_text, field: nil, value: "artist:", negate: false)]
      )
    end
  end

  describe ".classify_value" do
    it "klassifiziert einen einfachen Wert als contains" do
      expect(described_class.classify_value("jazz")).to eq(type: :contains, value: "jazz")
    end

    it "klassifiziert eine kommagetrennte Liste als ODER-Liste" do
      expect(described_class.classify_value("jazz,fusion,blues")).to eq(
        type: :list, values: %w[jazz fusion blues]
      )
    end

    it "klassifiziert min..max als Range" do
      expect(described_class.classify_value("80..100")).to eq(type: :range, min: "80", max: "100")
    end

    it "klassifiziert eine offene Range mit nur einem Ende" do
      expect(described_class.classify_value("80..")).to eq(type: :range, min: "80", max: nil)
      expect(described_class.classify_value("..100")).to eq(type: :range, min: nil, max: "100")
    end

    it "klassifiziert Vergleichsoperatoren" do
      expect(described_class.classify_value(">50")).to eq(type: :comparison, operator: ">", value: "50")
      expect(described_class.classify_value(">=50")).to eq(type: :comparison, operator: ">=", value: "50")
      expect(described_class.classify_value("<50")).to eq(type: :comparison, operator: "<", value: "50")
      expect(described_class.classify_value("<=50")).to eq(type: :comparison, operator: "<=", value: "50")
    end

    it "klassifiziert eine Liste aus gequotetem und ungequotetem Item, Anfuehrung entfernt (Bugfix)" do
      expect(described_class.classify_value('"A.J. Croce",Kingfish')).to eq(
        type: :list, values: ["A.J. Croce", "Kingfish"]
      )
    end

    it "behandelt ein einzelnes gequotetes Item mit Komma darin als contains, nicht als Liste" do
      expect(described_class.classify_value('"Earth, Wind & Fire"')).to eq(
        type: :contains, value: "Earth, Wind & Fire"
      )
    end
  end
end
