# frozen_string_literal: true

class Category < ApplicationRecord
  has_many :tags, dependent: :destroy

  # Wirkt nur auf die Zuweisungs-Suche (TagsController#search, Intent 82) - bestehende TrackTag-
  # Zuordnungen aus einer ausgeblendeten Kategorie bleiben unveraendert sichtbar, analog zum
  # Library-Import-/Anzeigefilter-Prinzip (siehe CLAUDE.md).
  scope :visible_for_assignment, -> { where(hidden_for_assignment: false) }

  validates :name, presence: true, uniqueness: true
  # Optional, aber wenn gesetzt muss es ein gueltiger Hex-Farbcode sein (3- oder 6-stellig,
  # mit oder ohne #) - dient nur als Hue-Anker fuer die Tag-Badges (TracksHelper#tag_badge_style),
  # ein ungueltiger Wert wuerde dort sonst zu einem Rendering-Fehler statt einer Validierungs-
  # meldung fuehren.
  validates :color, format: { with: /\A#?[0-9a-fA-F]{3}\z|\A#?[0-9a-fA-F]{6}\z/,
                              message: "muss ein gültiger Hex-Farbcode sein (z.B. #4a90d9 oder #4ad)" },
                    allow_blank: true
end
