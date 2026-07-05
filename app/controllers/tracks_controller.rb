# frozen_string_literal: true

class TracksController < ApplicationController
  PAGE_SIZE = 50
  AVAILABLE_FILTERS = %w[downloaded missing].freeze

  # Zeigt die letzten 50 gespielte Lieder
  # tracks sind RSpotify::Track
  def recently_played_index
    @tracks = current_user.spotify_user.recently_played(limit: 50) #=>
  end

  def index
    tracks = Track.for_index.search_query(params[:q]).sorted(params[:sort], params[:direction])
    @pagy, @tracks = paginate_for_index(tracks)
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
    return paginate_by_availability(tracks) if AVAILABLE_FILTERS.include?(params[:available])

    pagy, page_tracks = pagy(:offset, tracks, limit: PAGE_SIZE)
    Track.preload_track_paths(page_tracks)
    [pagy, page_tracks]
  end

  # Kein DB-Feld für "Datei vorhanden" (siehe CLAUDE.md/Intent 34) - filtert darum in Ruby auf
  # der bereits durchsuchten/sortierten Relation, statt einer neuen, mit dem Dateisystem zu
  # synchronisierenden Spalte. Ein einziger Verzeichnis-Scan für alle Treffer (preload) vor der
  # Pagination, damit das gefilterte Array danach keinen weiteren Scan mehr braucht.
  def paginate_by_availability(tracks)
    filtered = filter_by_availability(tracks.to_a, params[:available])
    pagy(:offset, filtered, limit: PAGE_SIZE)
  end

  def filter_by_availability(tracks, available)
    Track.preload_track_paths(tracks)
    available == "downloaded" ? tracks.select(&:track_path) : tracks.reject(&:track_path)
  end
end
