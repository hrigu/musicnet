# frozen_string_literal: true

module PlaylistsHelper
  COLORS = %i[green blue yellow red lila orange black brown].freeze

  # Saettigung fix, Helligkeit variiert pro einzelner Playlist (Intent 71 Nachtrag) - beim ersten
  # Anlauf (feste text-bg-*-Klassen aus einer Palette von 7) bekamen ausnahmslos ALLE Playlists mit
  # gleichem erstem Wort exakt dieselbe Farbe (z.B. jede einzelne Fusion-Playlist identisch gruen) -
  # das war zu grob, der DJ wollte jede Playlist einzeln unterscheidbar sehen, nur die Familie
  # (Farbton) sollte sich aehneln. Automatische Farbe daher als HSL statt fixer Bootstrap-Klasse:
  # Farbton (Hue) aus dem ersten Wort (Familie), Helligkeit aus dem vollen Namen (Individualitaet).
  AUTO_SATURATION = 55
  AUTO_LIGHTNESS_RANGE = (35..65)

  def playlist_short_name(playlist)
    playlist.name.gsub(/\bfusion\b/i, "_F_")
            .gsub(/\bblues\b/i, "_B_")
            .gsub(/\s+/, "")
            .gsub(/_+/, "_")
            .gsub(/\A_+/, "")
            .gsub(/_+\z/, "")
  end

  # Zentrales Badge-Markup (Intent 71) - ersetzt die zuvor an fuenf Stellen duplizierte
  # <span class="badge ...">-Zeile. DJ-Gig-Playlists (Name beginnt mit einer Jahreszahl) bekommen
  # einheitlich Grau (Nachtrag - vorher Schwarz), alles andere entweder die eigene Farbe
  # (playlist.color, falls gesetzt) oder die automatisch berechnete HSL-Farbe.
  # label ist per Default die Kurzform, kann aber ueberschrieben werden (z.B. der volle Name auf
  # der Track-Detailseite, wo Platz fuer Nachvollziehbarkeit wichtiger ist als Kompaktheit) - die
  # Farblogik bleibt in beiden Faellen dieselbe.
  def playlist_badge(playlist, label: playlist_short_name(playlist))
    if !playlist.color.present? && dj_playlist?(playlist.name)
      content_tag(:span, label, class: "badge text-bg-secondary")
    else
      content_tag(:span, label, class: "badge", style: playlist_badge_style(playlist))
    end
  end

  # Auch fuer die Vorschau im Farbwaehler auf der Bearbeiten-Seite genutzt (Intent 71 Nachtrag) -
  # ohne eigene Farbe zeigte der Farbwaehler zuvor immer Schwarz statt der tatsaechlich aktiven
  # automatischen Farbe.
  def playlist_badge_style(playlist)
    if playlist.color.present?
      "background-color: #{playlist.color}; color: #{contrasting_text_color(playlist.color)};"
    else
      hue, lightness = auto_hue_and_lightness(playlist.name)
      text_color = lightness > 55 ? "#000" : "#fff"
      "background-color: hsl(#{hue}, #{AUTO_SATURATION}%, #{lightness}%); color: #{text_color};"
    end
  end

  # Hex-Wert fuer den <input type="color">-Farbwaehler auf der Bearbeiten-Seite (Intent 71
  # Nachtrag) - der native Farbwaehler akzeptiert nur Hex-Werte, keine hsl()-Strings, und ohne das
  # zeigte er ohne eigene Farbe immer Schwarz statt der tatsaechlich aktiven Automatik-Farbe.
  def playlist_preview_color(playlist)
    return playlist.color if playlist.color.present?
    return "#6c757d" if dj_playlist?(playlist.name) # Bootstraps text-bg-secondary-Grau

    hue, lightness = auto_hue_and_lightness(playlist.name)
    hsl_to_hex(hue, AUTO_SATURATION, lightness)
  end

  # playlist_tracks braucht bereits preload_track_paths (siehe
  # Playlist#playlist_tracks_for_display), sonst pro Track ein Verzeichnis-Scan.
  def all_tracks_downloaded?(playlist_tracks)
    playlist_tracks.all? { |pt| pt.track.track_path.present? }
  end

  # playlist.tracks braucht bereits preload_track_paths (siehe PlaylistsController#index),
  # sonst ein Verzeichnis-Scan pro Track statt einem fürs ganze Batch (Intent 61).
  def downloaded_tracks_count(playlist)
    playlist.tracks.count { |track| track.track_path.present? }
  end

  private

  def checksum(str)
    str.each_byte.sum
  end

  def dj_playlist?(name)
    /^\d{4}/.match?(name)
  end

  def playlist_color_key(name)
    name.to_s.split(/\s+/).first.to_s.downcase
  end

  # Farbton (Hue) aus dem ersten Wort (Familie: aehnlich benannte Playlists teilen den Farbton),
  # Helligkeit aus dem vollen Namen (Individualitaet: einzelne Playlists derselben Familie
  # unterscheiden sich trotzdem, Intent 71 Nachtrag).
  def auto_hue_and_lightness(name)
    hue = checksum(playlist_color_key(name)) % 360
    lightness = AUTO_LIGHTNESS_RANGE.begin + (checksum(name) % AUTO_LIGHTNESS_RANGE.size)
    [hue, lightness]
  end

  # Einfache Helligkeitsformel (kein volles WCAG-Kontrastverhaeltnis noetig, nur schwarz-oder-weiss-
  # Entscheidung fuer den Badge-Text bei einer frei gewaehlten Hintergrundfarbe, Intent 71).
  def contrasting_text_color(hex)
    r, g, b = hex.delete("#").scan(/../).map { |c| c.to_i(16) }
    luminance = ((0.299 * r) + (0.587 * g) + (0.114 * b)) / 255
    luminance > 0.6 ? "#000" : "#fff"
  end

  # Standard HSL->RGB-Umrechnung (Intent 71 Nachtrag) - nur fuer den <input type="color">-
  # Farbwaehler gebraucht, der Badge selbst nutzt hsl() direkt als CSS-Wert.
  def hsl_to_hex(hue, saturation, lightness)
    sat = saturation / 100.0
    light = lightness / 100.0
    chroma = (1 - ((2 * light) - 1).abs) * sat
    intermediate = chroma * (1 - (((hue / 60.0) % 2) - 1).abs)
    offset = light - (chroma / 2)
    r, g, b = hsl_rgb_segment(hue, chroma, intermediate)
    [r, g, b].map { |v| ((v + offset) * 255).round.to_s(16).rjust(2, "0") }.join.then { |hex| "##{hex}" }
  end

  def hsl_rgb_segment(hue, chroma, intermediate)
    case hue
    when 0...60 then [chroma, intermediate, 0]
    when 60...120 then [intermediate, chroma, 0]
    when 120...180 then [0, chroma, intermediate]
    when 180...240 then [0, intermediate, chroma]
    when 240...300 then [intermediate, 0, chroma]
    else [chroma, 0, intermediate]
    end
  end
end
