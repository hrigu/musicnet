class DownloadPlaylistService
  TRACKS_DIR = 'downloads/tracks'

  # Wird geworfen, wenn bereits ein spotdl-Download läuft (parallele Prozesse
  # provozieren Spotify-Rate-Limits und YouTube-Blocks)
  DownloadAlreadyRunningError = Class.new(StandardError)

  # Prozessweiter Lock über alle spotdl-Downloads (Playlist-Download und Track-Nachladen)
  DOWNLOAD_LOCK = Mutex.new

  def initialize playlist
    @playlist = playlist
  end

  # lädt die Songs der @playlist runter und speichert sie unter downloads/tracks.
  # Tracks die schon vorhanden sind werden nicht nochmals runtergeladen
  def download
    with_download_lock do
      tracks_dir = Rails.root.join(TRACKS_DIR)
      Rails.logger.info "DownloadPlaylistService#download: current_dir = #{tracks_dir}"
      result = system(DownloadPlaylistCommandBuilder.new(@playlist).build, chdir: tracks_dir)
      Rails.logger.info(result)
      AudioFeaturesExtractionService.new(@playlist.tracks).extract_missing if result
    end
  end


  private

  # Verhindert parallele spotdl-Prozesse. try_lock statt lock, damit der zweite Aufruf
  # sofort mit einer verständlichen Meldung scheitert statt zu warten.
  def with_download_lock
    unless DOWNLOAD_LOCK.try_lock
      raise DownloadAlreadyRunningError, "Es läuft bereits ein Download - bitte warten, bis er fertig ist"
    end

    begin
      yield
    ensure
      DOWNLOAD_LOCK.unlock
    end
  end

end
