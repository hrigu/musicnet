class Category < ApplicationRecord
  has_many :tags, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  # Optional, aber wenn gesetzt muss es ein gueltiger Hex-Farbcode sein (3- oder 6-stellig,
  # mit oder ohne #) - dient nur als Hue-Anker fuer die Tag-Badges (TracksHelper#tag_badge_style),
  # ein ungueltiger Wert wuerde dort sonst zu einem Rendering-Fehler statt einer Validierungs-
  # meldung fuehren.
  validates :color, format: { with: /\A#?[0-9a-fA-F]{3}\z|\A#?[0-9a-fA-F]{6}\z/,
                               message: "muss ein gültiger Hex-Farbcode sein (z.B. #4a90d9 oder #4ad)" },
                     allow_blank: true
end
