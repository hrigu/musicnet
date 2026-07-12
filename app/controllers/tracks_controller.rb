# frozen_string_literal: true

class TracksController < ApplicationController
  PAGE_SIZE = 50
  RECENT_TAG_SUGGESTION_LIMIT = 5
  RECENTLY_PLAYED_TABS = %w[musicnet spotify].freeze

  # Zeigt die letzten 50 gespielte Lieder
  def recently_played_index
    @active_recently_played_tab = RECENTLY_PLAYED_TABS.include?(params[:tab]) ? params[:tab] : "musicnet"
    musicnet_playbacks = current_user.dj_session_playbacks.includes(track: %i[artists album]).recent_first.limit(100)
    @musicnet_session_groups = DjSessionPlayback.group_into_sessions(musicnet_playbacks.to_a)
    @spotify_tracks = load_spotify_recently_played
    @local_tracks_by_spotify_id = local_tracks_by_spotify_id(@spotify_tracks)
    # Fuer den "Vorhören"-Button (nur bei noch nicht heruntergeladenen Tracks) - ohne dieses
    # Preload wuerde jede Zeile track_path einzeln aufloesen, je ein eigener Verzeichnis-Scan
    # ueber downloads/tracks (siehe Track#track_path/.preload_track_paths).
    Track.preload_track_paths(@local_tracks_by_spotify_id.values)
  end

  def index
    tracks = Track.for_index.search_query(params[:q])
                  .in_active_library(current_user.active_library_id)
                  .sorted(params[:sort], params[:direction])
    @pagy, @tracks = paginate_for_index(tracks)
    @recent_tag_suggestions = Tag.recently_assigned_by(current_user, limit: RECENT_TAG_SUGGESTION_LIMIT)
  end

  def query_suggestions
    suggestions = TrackQuerySuggestions.for(params[:term], current_user.active_library_id)
    render json: { suggestions: suggestions }
  end

  # Laeuft im Hintergrund (DownloadMissingTracksJob, Intent 39) statt den Request zu blockieren -
  # ein Fehler im Job ist dadurch nicht mehr synchron abfangbar, daher der Guard vorab.
  def download
    return redirect_to tracks_path, alert: "Es läuft bereits ein Download - bitte warten, bis er fertig ist" if DownloadPlaylistService::DOWNLOAD_LOCK.locked?

    tracks_without_file = Track.for_download.reject(&:track_path)
    DownloadMissingTracksJob.perform_later(tracks_without_file)
    redirect_to tracks_path
  end

  # Importiert+laedt einen noch nicht lokalen Spotify-Track aus dem "Zuletzt gespielt"-Tab
  # herunter (Intent 88) - im Hintergrund. Kein Lock-Vorab-Check wie bei #download: mehrere Klicks
  # duerfen sich problemlos zu einer Warteschlange stapeln, da DownloadStandaloneTrackService#download
  # den DOWNLOAD_LOCK per Mutex#synchronize (blockierendes Warten) statt #try_lock nimmt - jeder
  # weitere Job wartet dort einfach, bis der vorherige fertig ist, statt mit einer Exception
  # abzubrechen (die im async-Job ohnehin unbehandelt bliebe, siehe #download-Kommentar).
  def import_from_spotify
    # Vor dem perform_later markieren, nicht erst im Job selbst: der Redirect danach ist quasi
    # sofort da, der :async-Adapter startet den Job aber erst etwas spaeter in einem Thread - ohne
    # diese Reihenfolge wuerde die neu geladene Seite die Zeile kurzzeitig faelschlicherweise noch
    # als "nicht pending" rendern.
    PendingSpotifyImports.add(params[:spotify_track_id])
    ImportAndDownloadSpotifyTrackJob.perform_later(params[:spotify_track_id])
    redirect_to recently_played_index_tracks_path(tab: "spotify")
  end

  def show
    @track = Track.for_show.find(params[:id])
    @recent_tag_suggestions = Tag.recently_assigned_by(current_user, limit: RECENT_TAG_SUGGESTION_LIMIT)
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

  def load_spotify_recently_played
    return [] unless @active_recently_played_tab == "spotify"

    recently_played = current_user.spotify_user.recently_played(limit: 50)
    prepend_now_playing(recently_played)
  end

  # GET /me/player liefert den aktuell aktiven Wiedergabezustand - ein komplett anderer Endpoint als
  # /me/player/recently-played oben, das nur eine rollierende Historie *abgeschlossener*
  # Wiedergaben ist und den gerade laufenden Track typischerweise noch nicht enthaelt.
  #
  # Bewusst *nicht* ueber RSpotify::User#player/RSpotify::Player: dessen #initialize liest den
  # Track aus options['track'], Spotifys tatsaechliche JSON-Antwort liefert ihn aber unter 'item'
  # (siehe Player#currently_playing weiter unten in der Gem, die es richtig macht -
  # Track.new response["item"]) - player.track ist dadurch in dieser Gem-Version (2.12.4) immer
  # nil, unabhaengig davon, was tatsaechlich laeuft (verifiziert per Konsole: is_playing true,
  # device korrekt, track nil). Deshalb hier der rohe JSON-Response direkt ueber das oeffentliche
  # RSpotify::User.oauth_get (kein eigener API-Call noetig, kein RSpotify.raw_response-Umschalten,
  # das als globaler Zustand parallele Requests auf anderen Threads beeinflussen wuerde).
  #
  # currently_playing_type wird zusaetzlich geprueft (nicht nur item.present?), weil Spotify auch
  # bei Werbung/Podcast-Episoden ein item mitliefert, dessen Form nicht der eines Tracks entspricht.
  # 204 (nichts aktiv) liefert send_request als nil zurueck, ebenso bei Pause is_playing == false -
  # beide Faelle bedeuten hier "nichts voranstellen". Ist der aktuelle Track zufaellig schon der
  # oberste Recently-Played-Eintrag (z.B. weil Spotify ihn zwischenzeitlich selbst schon als
  # abgeschlossen gelistet hat), wird er nicht doppelt vorangestellt.
  def prepend_now_playing(recently_played)
    response = RSpotify::User.oauth_get(current_user.spotify_user.id, "me/player")
    return recently_played unless response.is_a?(Hash) && response["is_playing"] &&
                                  response["currently_playing_type"] == "track" && response["item"]

    now_playing_track = RSpotify::Track.new(response["item"])
    @now_playing_spotify_id = now_playing_track.id
    return recently_played if recently_played.first&.id == now_playing_track.id

    [now_playing_track] + recently_played
  rescue RestClient::Unauthorized => e
    # Der user-read-playback-state-Scope wurde erst nachtraeglich ergaenzt (siehe
    # config/initializers/devise.rb) - bereits eingeloggte Sessions haben einen Access-Token ohne
    # diesen Scope und bekommen fuer /me/player ein 401, bis sie sich einmal neu einloggen. Gleiches
    # Soft-Failure-Prinzip wie ueberall sonst in dieser App (z.B. try_fetch/prefetch_details): eine
    # fehlende Randinformation blockiert nie die eigentliche Seite.
    Rails.logger.warn("TracksController#prepend_now_playing: #{e.message}")
    recently_played
  end

  # Ein einziger Query statt N+1 - @spotify_tracks sind transiente RSpotify::Track-Objekte, kein
  # ActiveRecord, darum kein includes/preload moeglich, nur ein direkter Abgleich per spotify_id.
  def local_tracks_by_spotify_id(spotify_tracks)
    return {} if spotify_tracks.empty?

    Track.where(spotify_id: spotify_tracks.map(&:id)).index_by(&:spotify_id)
  end

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
