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
      result = system(build_command, chdir: tracks_dir)
      Rails.logger.info(result)
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

  def build_command
    o = {
      main_option: 'sync', #Removes songs that are no longer present, downloads new ones
      save_file: "--save-file #{@playlist.name_path_ready}.spotdl", #The file to save/load the songs data from/to. It has to end with .spotdl. If combined with the download operation, it will save the songs data to the file. Required for save/preload/sync
      sync_without_deleting: '--sync-without-deleting', #Sync without deleting songs that are not in the query.
      user_auth: '--user-auth',           #Login to Spotify using OAuth.
      format: '--format m4a'
  }

    playlist_url = @playlist.url
    playlist_url = "https://open.spotify.com/playlist/#{@playlist.spotify_id}" unless playlist_url

    cmd = "spotdl #{o[:main_option]} #{playlist_url} #{o[:save_file]} #{o[:sync_without_deleting]} #{o[:user_auth]} #{o[:format]}"
    Rails.logger.info cmd
    cmd
  end


end
