class Tag < ApplicationRecord
  belongs_to :category
  has_many :track_tags, dependent: :destroy
  has_many :tracks, through: :track_tags

  validates :name, presence: true, uniqueness: { scope: :category_id }
  validates :aliases, presence: true

  # Zerlegt die Komma-Liste aus dem Admin-Formular in einzelne, getrimmte Roh-Aliase.
  def alias_list
    aliases.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  # Wortgrenzen statt Teilstring-Vergleich (anders als Library#matching): die Taxonomie enthaelt
  # bereits eine reale Kollision ("Salsadancers" enthaelt den Teilstring "sad") - ein reiner
  # include?-Vergleich wuerde hier faelschlich matchen. normalized_name wird vom Aufrufer
  # uebergeben, damit die teure Normalisierung einmal pro Playlist statt einmal pro
  # (Tag x Playlist)-Paar passiert.
  def matches_normalized_name?(normalized_name)
    alias_list.any? do |raw_alias|
      normalized_alias = self.class.normalize(raw_alias)
      next false if normalized_alias.blank?

      normalized_name.match?(/\b#{Regexp.escape(normalized_alias)}\b/)
    end
  end

  def self.matching(playlist_name)
    normalized_name = normalize(playlist_name)
    all.select { |tag| tag.matches_normalized_name?(normalized_name) }
  end

  # Normalisiert Playlist-Namen UND Aliase auf dieselbe Weise vor dem Vergleich: Apostrophe/
  # Bindestriche/Unterstriche/Schraegstriche werden zu Leerzeichen (nicht entfernt!), sonst
  # wuerde z.B. "rock'n'roll" zu einem Wort verschmelzen und seine Wortgrenze verlieren.
  def self.normalize(text)
    text.to_s.downcase.gsub(/['’_\-\/]/, " ").squeeze(" ").strip
  end
end
