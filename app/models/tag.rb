# frozen_string_literal: true

class Tag < ApplicationRecord
  belongs_to :category
  has_many :tag_assignments, dependent: :destroy
  has_many :track_tags, dependent: :destroy
  has_many :tracks, through: :track_tags

  validates :name, presence: true, uniqueness: { scope: :category_id }
  validates :aliases, presence: true

  scope :assignable, -> { where(assignable: true) }

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

  # Liefert die zuletzt manuell vergebenen Tags eines Users in eindeutiger Form und filtert dabei
  # bereits gesperrte Tags, ausgeblendete Kategorien und optional bereits am Track vorhandene Tags
  # heraus, damit die Vorschlagsliste spaeter direkt fuer beide Zuweisungs-Flows nutzbar ist.
  def self.recently_assigned_by(user, limit:, exclude_track: nil)
    scope = joins(:tag_assignments, :category)
            .merge(Category.visible_for_assignment)
            .assignable
            .where(tag_assignments: { user_id: user.id })
    scope = scope.where.not(id: exclude_track.tag_ids) if exclude_track

    scope.group("tags.id").order(Arel.sql("MAX(tag_assignments.created_at) DESC")).limit(limit)
  end

  # Normalisiert Playlist-Namen UND Aliase auf dieselbe Weise vor dem Vergleich: Apostrophe/
  # Bindestriche/Unterstriche/Schraegstriche werden zu Leerzeichen (nicht entfernt!), sonst
  # wuerde z.B. "rock'n'roll" zu einem Wort verschmelzen und seine Wortgrenze verlieren.
  def self.normalize(text)
    text.to_s.downcase.gsub(%r{['’_\-/]}, " ").squeeze(" ").strip
  end
end
