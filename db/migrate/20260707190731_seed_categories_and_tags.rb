# frozen_string_literal: true

# Seedet die kuratierte Kategorien/Tag-Taxonomie (Intent 77), abgeleitet aus einer Analyse aller
# Playlist-Namen. Lokale Modelle statt der App-Models, damit diese Migration auch nach spaeteren
# Aenderungen an Category/Tag unveraendert lauffaehig bleibt (gleiches Muster wie
# SeedLibrariesAndAssignExistingPlaylists, Intent 57). find_or_create_by! statt create!, damit ein
# versehentliches erneutes Ausfuehren bereits im Admin-UI bearbeitete Zeilen NICHT ueberschreibt -
# nur fehlende Categories/Tags werden nachgezogen, vorhandene bleiben unangetastet.
class SeedCategoriesAndTags < ActiveRecord::Migration[8.1]
  class MigrationCategory < ActiveRecord::Base
    self.table_name = "categories"
  end

  class MigrationTag < ActiveRecord::Base
    self.table_name = "tags"
  end

  TAXONOMY = {
    "Instrumentierung" => {
      "Piano" => "piano",
      "Violine" => "violin, violine, geige",
      "Brass" => "brass",
      "A-cappella" => "a capella, accapella",
      "Akustisch" => "accustic, acoustic",
      "Instrumental" => "instrumental"
    },
    "Emotion/Stimmung" => {
      "Sweet" => "sweet",
      "Angry" => "angry",
      "Traurig" => "sad",
      "Happy" => "happy",
      "Love" => "love",
      "Melancholisch" => "melancolic, melancolia, melancholia",
      "Dark" => "dark",
      "Mysteriös" => "mystery",
      "Dramatisch" => "drama",
      "Cool" => "cool",
      "Chillig" => "chill",
      "Romantisch" => "romantik",
      "Zart" => "tender, zart",
      "Kitschig" => "kitsch",
      "Naiv" => "naive",
      "Opulent" => "opulent",
      "Humorvoll" => "humor",
      "Skurril" => "skurril",
      "Verspielt" => "verspielt",
      "Hypnotisch" => "hypnotisch",
      "Hymnisch" => "hymnisch",
      "Schnulzig" => "schnulzen",
      "Smooth" => "smooth",
      "Robust" => "robust",
      "Lüpfig" => "lüpfig"
    },
    "Qualität/Level" => {
      "Beste" => "best",
      "Mässig" => "mässig",
      "Kandidat" => "kandidaten",
      "Next Big Thing" => "next big thing",
      "Zum Üben" => "practicing",
      "Tanzbar" => "dancing, tanzbar",
      "Gerade" => "gerade",
      "Verswingt" => "verswingt",
      "Einfach" => "simple",
      "Jung" => "young"
    },
    "Tempo/Energie" => {
      "Schnell" => "fast, schnell",
      "Langsam" => "slow",
      "Slow Drag" => "drag",
      "Heavy" => "heavy, fett",
      "Leicht" => "light",
      "Energiegeladen" => "energie",
      "Groove" => "groove",
      "Unregelmässiger Takt" => "unregelmässiger",
      "6/8-Takt" => "6 8"
    },
    "Geografie/Kultur" => {
      "Afrika" => "africa",
      "Karibik" => "karibik",
      "Schweiz" => "suisse",
      "Arabisch" => "arabisch",
      "Spanisch" => "spanish",
      "Französisch" => "french, francais",
      "Texas" => "texas",
      "Hillcountry" => "hillcountry",
      "Delta" => "delta",
      "Piedmont" => "piedmont",
      "Swamp" => "swamp",
      "Mardi Gras" => "mardi gras",
      "Worldmusic" => "worldmusic"
    },
    "Musikstil/Genre" => {
      "Jazz" => "jazz",
      "Rock" => "rock",
      "Punk" => "punk",
      "Reggae" => "reggea",
      "Latin" => "latin",
      "Hiphop" => "hiphop",
      "Techno" => "techno",
      "Triphop" => "triphop",
      "Swing" => "swing",
      "Tango" => "tango",
      "Walzer" => "waltz, walzer",
      "Country" => "country",
      "Gospel" => "gospel",
      "Folk" => "folk",
      "Soul" => "soul",
      "Funk" => "funk, funky",
      "Boogie" => "boogie",
      "Ragtime" => "ragtime",
      "Shuffle" => "shuffle",
      "R&B" => "r&b",
      "Elektro" => "elektro",
      "Electronica" => "electronica",
      "Noise" => "noise",
      "Avantgarde" => "avantgarde",
      "Experimentell" => "experimental, experimentell",
      "Crossover" => "crossover",
      "Pop" => "pop",
      "Cover" => "cover, covers",
      "Klassiker" => "classic, klassiker",
      "Renaissance" => "renaissance",
      "Contemporary Classical" => "contemporary",
      "History" => "history",
      "Struttin" => "struttin",
      "Balladen" => "balads",
      "Alternative" => "alternative",
      "Hits" => "hits",
      "Rolling Stones" => "rolling stones",
      "Mainstream" => "mainstream",
      "80er" => "80ies",
      "Singer-Songwriter" => "singer songwriter",
      "Frühwerk" => "early stuff"
    },
    "Person/Widmung" => {
      "Karl" => "karl",
      "Paula" => "paula",
      "Maria" => "maria",
      "Nisha & Sandra" => "nisha und sandra"
    },
    "Funktion/Setzweck" => {
      "Vorbereitet" => "vorbereitet",
      "Spezial" => "achtung",
      "Zugabe/Schluss" => "encore, schluss",
      "Best-of" => "bestof",
      "In Memoriam" => "memoriam",
      "DJ Set" => "dj set"
    },
    "Bildhaft/Motiv" => {
      "Angel" => "angel",
      "Dream" => "dream",
      "Jungle" => "jungle",
      "Story" => "story",
      "Melody" => "melody",
      "Lied" => "lied, liedchen",
      "Song" => "song",
      "Texture" => "texture",
      "Space Kitty" => "space kitty"
    },
    "Textur/Klangcharakter" => {
      "Micro" => "micro",
      "Minimalistisch" => "minimalistic",
      "Monoton" => "monoton",
      "Smart" => "smart",
      "Floating" => "floating",
      "Naked" => "naked",
      "Soft/Weich" => "soft weich"
    },
    "Thema/Gesellschaft" => {
      "Politisch" => "political",
      "Frauen" => "woman, ladies"
    },
    "Anlass/Ort" => {
      "Pusterum" => "pusterum",
      "Rebelblues" => "rebelblues",
      "Rebel" => "rebel",
      "Mattebrennerei" => "mattebrennerei",
      "Salsadancers" => "salsadancers",
      "Fusionizers" => "fusionizers",
      "Bebluesed" => "bebluesed",
      "Fuse the Blues" => "fuse the blues",
      "Café2" => "café",
      "Party" => "party"
    }
  }.freeze

  EVENT_CATEGORIES = ["Anlass/Ort"].freeze

  def up
    TAXONOMY.each do |category_name, tags|
      category = MigrationCategory.find_or_create_by!(name: category_name) do |c|
        c.is_event = EVENT_CATEGORIES.include?(category_name)
      end

      tags.each do |tag_name, alias_list|
        MigrationTag.find_or_create_by!(category_id: category.id, name: tag_name) do |t|
          t.aliases = alias_list
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
