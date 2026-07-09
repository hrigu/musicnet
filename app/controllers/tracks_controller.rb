# frozen_string_literal: true

class TracksController < ApplicationController
  PAGE_SIZE = 50

  # Zeigt die letzten 50 gespielte Lieder
  # tracks sind RSpotify::Track
  def recently_played_index
    @tracks = current_user.spotify_user.recently_played(limit: 50) #=>
  end

  def index
    tracks = Track.for_index.search_query(params[:q])
                  .in_active_library(current_user.active_library_id)
                  .sorted(params[:sort], params[:direction])
    @pagy, @tracks = paginate_for_index(tracks)
  end

  def query_suggestions
    suggestions = TrackQuerySuggestions.for(params[:term], current_user.active_library_id)
    render json: { suggestions: suggestions }
  end

  # Laeuft im Hintergrund (DownloadMissingTracksJob, Intent 39) statt den Request zu blockieren -
  # ein Fehler im Job ist dadurch nicht mehr synchron abfangbar, daher der Guard vorab.
  def download
    if DownloadPlaylistService::DOWNLOAD_LOCK.locked?
      return redirect_to tracks_path, alert: "Es läuft bereits ein Download - bitte warten, bis er fertig ist"
    end

    tracks_without_file = Track.for_download.reject(&:track_path)
    DownloadMissingTracksJob.perform_later(tracks_without_file)
    redirect_to tracks_path
  end

  def show
    @track = Track.for_show.find(params[:id])
    # Ids aus dem bereits preload-eten playlist_tracks ableiten statt @track.playlist_ids zu
    # nutzen - :playlists ist eine eigene Assoziation, die Track.for_show nie preload-et, ein
    # Zugriff wuerde also sowohl eine zusaetzliche Query als auch einen strict_loading-Fehler
    # ausloesen.
    # .to_a laedt sofort - ohne das wuerden @addable_playlists.any? (Vorhanden-Check) und .map
    # (Options-Aufbau) in der View je eine eigene Query ausloesen, statt sich eine geladene
    # Ergebnisliste zu teilen.
    @addable_playlists = Playlist.where.not(id: @track.playlist_tracks.map(&:playlist_id)).order(:name).to_a
    load_related_tracks
  end

  def cover
    image = Track.find(params[:id]).cover_image
    return head :not_found unless image

    send_data image[:data], type: image[:mime_type], disposition: "inline"
  end

  # send_file allein unterstuetzt keine HTTP-Range-Requests (nur ueber X-Sendfile/einen
  # vorgeschalteten Webserver, den es hier nicht gibt) - ohne Range-Support kann der Browser beim
  # Abspielen nicht an eine beliebige Stelle im Track springen (Intent 41: gemeldeter Seek-Bug im
  # globalen Player), da <audio> fuers Seeken gezielt einen Byte-Bereich nachladen muss, statt die
  # ganze Datei erneut zu laden.
  def stream
    track = Track.find(params[:id])
    track_path = track.track_path
    return unless track_path

    send_track_file_with_range_support(track_path)
  end

  private

  def send_track_file_with_range_support(path)
    response.headers["Accept-Ranges"] = "bytes"
    range = single_requested_range(path)
    return send_file(path) unless range

    response.headers["Content-Range"] = "bytes #{range.begin}-#{range.end}/#{File.size(path)}"
    send_data File.binread(path, range.size, range.begin), status: :partial_content
  end

  def single_requested_range(path)
    ranges = Rack::Utils.get_byte_ranges(request.headers["Range"], File.size(path))
    ranges&.first if ranges&.size == 1
  end

  def paginate_for_index(tracks)
    pagy, page_tracks = pagy(:offset, tracks, limit: PAGE_SIZE)
    Track.preload_track_paths(page_tracks)
    [pagy, page_tracks]
  end

  # Intent 84 (Stufe 1 + Nachtrag) - Rangliste statt Karte, siehe RelatedTracksFinder. @categories
  # fuers Filterformular bewusst auf die eigenen Tag-Kategorien des Tracks eingeschraenkt (nicht
  # alle Kategorien im System) - eine Kategorie, die der Ausgangstrack gar nicht traegt, kann per
  # Definition keine gemeinsamen Tags liefern und waere nur Rauschen in der Auswahl. @relevant_category_ids
  # (die per Filter gewaehlten, sonst alle eigenen) grenzt zusaetzlich die je Zeile angezeigten Tags
  # ein - nur Tags aus Kategorien, die tatsaechlich in die Berechnung eingeflossen sind.
  def load_related_tracks
    own_category_ids = @track.tag_category_ids
    @categories = Category.where(id: own_category_ids).order(:name)
    @relevant_category_ids = selected_related_category_ids || own_category_ids
    finder = RelatedTracksFinder.new(@track, category_ids: params[:related_category_ids],
                                             attribute_weights: selected_related_attribute_weights)
    @related_tracks = finder.call
    @related_active_comparison_count = finder.active_comparison_count
    @related_additional_tied_count = finder.additional_tied_count
    Track.preload_track_paths(@related_tracks.map { |r| r[:track] })
  end

  def selected_related_category_ids
    Array(params[:related_category_ids]).map(&:to_i).presence
  end

  # Nur Attribute, die per Checkbox aktiviert wurden, werden ueberhaupt an RelatedTracksFinder
  # weitergereicht - ein blosses Gewicht im Formular ohne angehaktes Attribut darf nichts bewirken
  # (Intent 84 Nachtrag 5).
  def selected_related_attribute_weights
    Array(params[:related_attribute_ids]).index_with { |key| params.dig(:related_attribute_weights, key) }
  end
end
