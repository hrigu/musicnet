# frozen_string_literal: true

class PlaylistsController < ApplicationController
  # Flash landet in der (clientseitigen) Session-Cookie - bei grossen Playlists sprengen zu
  # viele Eintraege deren ~4KB-Limit (ActionDispatch::Cookies::CookieOverflow), daher gedeckelt.
  MAX_FLASH_ENTRIES = 8

  # Redirect-nach-Mutation statt direktem Render (Intent 37/38, siehe refresh/download unten) -
  # vorher fehlte das hier und der data-turbo-method:-post-Link liess den Sync ohne sichtbares
  # Feedback verschwinden (Intent 58).
  def fetch_all
    info = BuildMusicNetService.new(current_user).build
    redirect_to playlists_path, notice: fetch_all_summary(info)
  rescue BuildMusicNetService::SyncAlreadyRunningError => e
    redirect_to playlists_path, alert: e.message
  end

  def index
    @playlists = Playlist.for_index.in_active_library(current_user.active_library_id)
                         .includes(:libraries, :tracks)
    tracks = @playlists.flat_map(&:tracks)
    ActiveRecord::Associations::Preloader.new(records: tracks, associations: :artists).call
    Track.preload_track_paths(tracks)
  end

  def show
    @playlist = Playlist.find(params[:id])
    @playlist_tracks = @playlist.playlist_tracks_for_display
  end

  # Gleicht die Playlist mit Spotify ab; das Ergebnis wird als Flash auf die
  # (redirectete) Playlist-Seite mitgegeben - direktes render nach einem POST
  # spielt schlecht mit Turbo zusammen (siehe Intent 37).
  def refresh
    @playlist = Playlist.find(params[:id])
    info = BuildMusicNetService.new(current_user).refresh_playlist(@playlist)
    set_refresh_flash(info)
    redirect_to playlist_path(@playlist)
  rescue BuildMusicNetService::PlaylistNotFoundError, BuildMusicNetService::SyncAlreadyRunningError => e
    redirect_to playlist_path(@playlist), alert: e.message
  end

  def edit
    @playlist = Playlist.find(params[:id])
  end

  def update
    @playlist = Playlist.find(params[:id])
    push_rename if renaming?
    update_color
    redirect_to playlists_path
  rescue SpotifyPlaylistsGateway::SpotifyWriteError, BuildMusicNetService::SyncAlreadyRunningError => e
    flash.now[:alert] = e.message
    render :edit, status: :unprocessable_content
  end

  # Lädt fehlende Tracks der Playlist runter; das Ergebnis (heruntergeladen/fehlgeschlagen)
  # wird wie bei refresh als Flash auf die Playlist-Seite mitgegeben (Intent 38).
  def download
    @playlist = Playlist.find(params[:id])
    result = DownloadPlaylistService.new(@playlist).download
    set_download_flash(result) if result
    redirect_to playlist_path(@playlist)
  rescue DownloadPlaylistService::DownloadAlreadyRunningError => e
    redirect_to playlist_path(@playlist), alert: e.message
  end

  private

  # :color leer ("") bedeutet "automatische Farbe" - Playlist#color.blank? behandelt das wie nil,
  # kein Sonderfall noetig (Intent 71).
  def playlist_params
    params.require(:playlist).permit(:name, :color)
  end

  def renaming?
    new_name.present? && new_name != @playlist.name
  end

  def new_name
    playlist_params[:name]
  end

  def push_rename
    PlaylistSpotifyWriteService.new(current_user).rename!(@playlist, new_name)
  end

  def update_color
    @playlist.update!(color: playlist_params[:color]) if playlist_params.key?(:color)
  end

  RESOURCE_LABELS = { playlists: "Playlists", tracks: "Tracks", artists: "Artists", albums: "Alben" }.freeze
  ACTION_LABELS = { created: "neu", deleted: "gelöscht" }.freeze

  # Bloss Anzahlen, keine Namenslisten wie bei set_download_flash/set_refresh_flash unten - ein
  # erster Voll-Import kann tausende Namen umfassen (Intent 33), das wuerde das ~4KB-Flash-Cookie-
  # Limit sprengen (CookieOverflow, siehe Intent 38). ServiceInfo#add haengt bei Einzel-Aufrufen
  # (add_new_created_*) flache Namens-Arrays an, bei den Loesch-Pfaden dagegen ein verschachteltes
  # Array (die ganze Namensliste als ein Element) - .flatten.size liefert in beiden Faellen die
  # richtige Anzahl, ohne ServiceInfo selbst anzufassen.
  def fetch_all_summary(info)
    parts = info.hash.flat_map do |resource, actions|
      actions.filter_map do |action, entries|
        count = entries.flatten.size
        next if count.zero?

        "#{count} #{RESOURCE_LABELS.fetch(resource, resource)} #{ACTION_LABELS.fetch(action, action)}"
      end
    end
    return "Sync abgeschlossen: keine Änderungen." if parts.empty?

    "Sync abgeschlossen: #{parts.join(', ')}."
  end

  def set_refresh_flash(info)
    flash[:refresh_added] = info.added
    flash[:refresh_removed] = info.removed
  end

  def set_download_flash(result)
    flash[:download_added] = result.downloaded.first(MAX_FLASH_ENTRIES)
    flash[:download_added_total] = result.downloaded.size
    flash[:download_failed] = result.failed.first(MAX_FLASH_ENTRIES)
    flash[:download_failed_total] = result.failed.size
  end
end
