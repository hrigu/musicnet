# frozen_string_literal: true

module TracksHelper
  def sort_link(column, label)
    active = active_sort_column == column
    next_direction = active && active_sort_direction == "asc" ? "desc" : "asc"
    query = request.query_parameters.merge("sort" => column, "direction" => next_direction).except("page")
    indicator = sort_indicator(active)

    link_to("#{label}#{indicator}", tracks_path(query))
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
