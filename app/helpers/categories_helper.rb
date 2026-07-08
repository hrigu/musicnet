# frozen_string_literal: true

module CategoriesHelper
  # Der native <input type="color">-Farbwaehler akzeptiert nur einen vollen 6-stelligen Hex-Wert
  # mit # - ohne eigene Farbe zeigte er sonst immer Schwarz statt eines neutralen Startwerts, und
  # eine gespeicherte 3-stellige Kurzform (z.B. "#c9f") wuerde er als ungueltig verwerfen.
  def category_preview_color(category)
    return "#6c757d" if category.color.blank? # Bootstraps text-bg-secondary-Grau

    digits = category.color.delete("#")
    digits = digits.chars.map { |c| c * 2 }.join if digits.length == 3
    "##{digits}"
  end
end
