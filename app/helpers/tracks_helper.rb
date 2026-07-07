# frozen_string_literal: true

module TracksHelper
  # "Zart haltend" (Wunsch des DJs): Kategorie-Farbe ist nur der Farbton (Hue), Saettigung und
  # Helligkeit sind bewusst weich/gedaempft statt kraeftig - anders als die Playlist-Badges
  # (AUTO_SATURATION 55, Intent 71), die einzelne Playlists auf einen Blick unterscheidbar
  # machen sollen. Hier stehen mehrere Tags derselben Kategorie oft direkt nebeneinander und
  # sollen als Familie zusammengehoerig wirken, nicht gegeneinander konkurrieren.
  TAG_AUTO_SATURATION = 35
  TAG_AUTO_LIGHTNESS_RANGE = (55..80)

  # Delegiert an User#column_visible? (Intent 80) - eigene Helper-Methode, damit Views nicht
  # direkt current_user.column_visible?(...) aufrufen muessen und ein spaeterer Wechsel der
  # Persistenz (z.B. weg vom User-Model) nur hier angepasst werden muesste.
  def column_visible?(key)
    current_user.column_visible?(key)
  end

  def sort_link(column, label)
    active = active_sort_column == column
    next_direction = active && active_sort_direction == "asc" ? "desc" : "asc"
    query = request.query_parameters.merge("sort" => column, "direction" => next_direction).except("page")
    indicator = sort_indicator(active)

    link_to("#{label}#{indicator}", url_for(query))
  end

  def genre_badge(genre)
    return content_tag(:span, "–", class: "text-muted") if genre.blank?

    content_tag(:span, genre, class: "badge rounded-pill text-bg-light border text-truncate", title: genre)
  end

  def track_meter(value, variant:)
    return content_tag(:span, "–", class: "text-muted") if value.nil?

    content_tag(:div, class: "d-flex align-items-center gap-2 track-meter") do
      progress = content_tag(:div, class: "progress flex-grow-1") do
        content_tag(:div, "", class: "progress-bar bg-#{variant}", style: "width: #{value}%")
      end
      progress + content_tag(:span, value, class: "small text-muted")
    end
  end

  # Fuer die Kategorien-Verwaltung (kein Track-Kontext, keine Staerke) - zeigt trotzdem schon die
  # abgeleitete Variante, damit die Wirkung der Kategorie-Farbe direkt in der Verwaltung sichtbar
  # ist, nicht erst auf der Trackliste.
  def tag_badge(tag)
    style = tag_badge_style(tag)
    if style
      content_tag(:span, tag.name, class: "badge rounded-pill", style: style)
    else
      content_tag(:span, tag.name, class: "badge rounded-pill text-bg-light border")
    end
  end

  # Fuer die Anzeige an einem konkreten Track - inkl. Staerke.
  def track_tag_badge(track_tag)
    label = "#{track_tag.tag.name} · #{track_tag.strength}"
    style = tag_badge_style(track_tag.tag)

    if style
      content_tag(:span, label, class: "badge rounded-pill", style: style)
    else
      content_tag(:span, label, class: "badge rounded-pill text-bg-light border")
    end
  end

  # Gruppiert die TrackTags eines Tracks nach Kategorie und sortiert die Gruppen alphabetisch
  # nach Kategorie-Name - mehrere Tags derselben Kategorie (z.B. zwei Emotion/Stimmung-Tags)
  # sollen zusammen unter einer Kategorie-Beschriftung stehen statt als lose Badge-Liste.
  def track_tags_by_category(track)
    track.track_tags.group_by { |tt| tt.tag.category }.sort_by { |category, _| category.name }
  end

  def artist_names_for(track)
    track.artists.map(&:name).join(", ")
  end

  # Nutzt playlist_tracks, falls das (z.B. auf /tracks) bereits preloaded ist, sonst playlists
  # (z.B. auf tracks#show) - je nach Aufrufkontext ist nur eine der beiden Assoziationen preloaded
  # und die andere wuerde mit strict_loading einen Fehler auslösen.
  def playlist_names_for(track)
    playlists = if track.association(:playlist_tracks).loaded?
                  track.playlist_tracks.map(&:playlist)
                else
                  track.playlists
                end
    playlists.map { |playlist| playlist_short_name(playlist) }.join(", ")
  end

  private

  # Leitet aus der Kategorie-Farbe (nur als Hue-Anker genutzt, nicht als exakter Badge-Ton) eine
  # zarte, tag-individuelle Variante ab - Farbton fix pro Kategorie (Familie), Helligkeit variiert
  # pro Tag-Name (Individualitaet), exakt dieselbe Idee wie PlaylistsHelper#auto_hue_and_lightness
  # (Intent 71), nur mit einem festen statt einem aus dem Namen abgeleiteten Hue. nil, wenn die
  # Kategorie keine Farbe gesetzt hat - der Aufrufer faellt dann auf ein neutrales Badge zurueck.
  def tag_badge_style(tag)
    color = tag.category.color
    return nil if color.blank?

    hue = hue_from_hex(color)
    lightness = TAG_AUTO_LIGHTNESS_RANGE.begin + (checksum(tag.name) % TAG_AUTO_LIGHTNESS_RANGE.size)
    text_color = lightness > 60 ? "#000" : "#fff"
    "background-color: hsl(#{hue}, #{TAG_AUTO_SATURATION}%, #{lightness}%); color: #{text_color};"
  end

  # Reine Hue-Extraktion aus einem Hex-Wert (Standard RGB->HSL-Formel, nur der Hue-Teil) - die
  # Kategorie-Farbe dient nur als Farbton-Anker, Saettigung/Helligkeit kommen von
  # TAG_AUTO_SATURATION/TAG_AUTO_LIGHTNESS_RANGE oben.
  def hue_from_hex(hex)
    digits = hex.delete("#")
    digits = digits.chars.map { |c| c * 2 }.join if digits.length == 3
    r, g, b = digits.scan(/../).map { |c| c.to_i(16) / 255.0 }
    max = [r, g, b].max
    min = [r, g, b].min
    delta = max - min
    return 0 if delta.zero?

    hue = case max
          when r then 60 * (((g - b) / delta) % 6)
          when g then 60 * (((b - r) / delta) + 2)
          else 60 * (((r - g) / delta) + 4)
          end
    hue.round % 360
  end

  def sort_indicator(active)
    return "" unless active

    active_sort_direction == "asc" ? " ▲" : " ▼"
  end

  def active_sort_column
    Track::SORT_COLUMNS.key?(params[:sort]) ? params[:sort] : Track::DEFAULT_SORT_COLUMN
  end

  def active_sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
  end
end
