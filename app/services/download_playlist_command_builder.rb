# frozen_string_literal: true

class DownloadPlaylistCommandBuilder
  # Fallback-Kette, falls einzelne Tracks oder die IP blockiert werden
  # (siehe doc/diary.md, Eintrag zu YouTube-Blocking) - spotdl versucht die
  # Provider in dieser Reihenfolge, bis einer einen Treffer liefert.
  # "youtube-music" bewusst ausgeschlossen: spotdl macht dafuer vorab einen
  # harten Connectivity-Check (entry_point.py) und bricht den GESAMTEN Lauf ab,
  # sobald der Provider in der Liste steht und der Check fehlschlaegt - auch
  # wenn er nicht an erster Stelle steht.
  # "soundcloud" bewusst ausgeschlossen: jeder Provider wird beim Start eager
  # instanziiert (nicht erst bei Bedarf), und die installierte soundcloud-v2-
  # Lib kann aktuell keine client_id mehr aus SoundClouds JS scrapen
  # (ClientIDGenerationError) - das reisst den gesamten Lauf mit, sobald der
  # Provider konfiguriert ist, unabhaengig davon ob ein Track ihn braucht.
  # "piped" bewusst ausgeschlossen: nutzt oeffentliche, instabile Piped-Instanzen;
  # eine tote Instanz wirft eine unabgefangene JSONDecodeError, die - wie bei
  # youtube-music/soundcloud - die Suche fuer den Track sofort abbricht statt
  # zum naechsten Provider (bandcamp) zu wechseln.
  AUDIO_PROVIDERS = 'youtube bandcamp'

  # Ab wie vielen fehlenden Tracks weiterhin die ganze Playlist gesynct wird statt
  # gezielter Track-URLs. Einzelne Track-URLs loesen bei spotdl pro URL eigene
  # Spotify-API-Calls aus (Track/Album/Artist), waehrend ein Playlist-Sync die ganze
  # Playlist gebuendelt holt - mit ~37 Track-URLs auf einmal gab es deswegen 2024
  # eine 24h-Rate-Limit-Sperre (Intent 21). 10 haelt deutlich Abstand dazu.
  SMALL_BATCH_THRESHOLD = 10

  attr_reader :save_file_path, :errors_file_path, :missing_tracks

  def initialize(playlist)
    @playlist = playlist
    @missing_tracks = playlist.missing_tracks
    @save_file_path = small_batch? ? "playlist_#{@playlist.id}_missing.spotdl" : save_file
    @errors_file_path = small_batch? ? "playlist_#{@playlist.id}_missing-errors.txt" : sync_errors_file_path
  end

  # --simple-tui auf beiden Varianten: system(...) leitet stdout nicht um, spotdl erbt es also
  # direkt vom Rails-Prozess. Ohne dieses Flag rendert spotdl einen animierten Rich-Fortschritts-
  # balken, der eine echte interaktive TTY mit In-Place-Redraw voraussetzt - landet die Ausgabe
  # stattdessen in einem Log, wird jeder Redraw-Tick als eigener, kompletter Textblock angehaengt
  # (Intent 60). --simple-tui liefert stattdessen eine Zeile pro Ereignis.
  def build
    if small_batch?
      build_track_urls_command
    else
      build_sync_command
    end
  end

  # true, wenn gezielte Track-URLs statt eines vollen Playlist-Syncs gebaut werden -
  # bestimmt, ob die Save-Datei danach als temporaer (loeschbar) gilt (siehe
  # DownloadResultParser#cleanup_save_file).
  def small_batch?
    @missing_tracks.any? && @missing_tracks.size <= SMALL_BATCH_THRESHOLD
  end

  private

  # Track-Metadaten sind auf Spotify immer oeffentlich (anders als Playlists) -
  # kein --user-auth noetig. Kein --sync-without-deleting, da hier explizit nur
  # die fehlenden Tracks angefragt werden, keine Lösch-Reconciliation stattfindet.
  def build_track_urls_command
    urls = @missing_tracks.map { |track| track_url(track) }.join(' ')
    "spotdl download #{urls} --format m4a --audio #{AUDIO_PROVIDERS} " \
      "--save-file #{save_file_path} --save-errors #{errors_file_path} --simple-tui"
  end

  def build_sync_command
    "spotdl sync #{playlist_url} --save-file #{save_file_path} --sync-without-deleting" \
      "#{user_auth_flag} --format m4a --audio #{AUDIO_PROVIDERS} --save-errors #{errors_file_path} --simple-tui"
  end

  def track_url(track)
    track.url || "https://open.spotify.com/track/#{track.spotify_id}"
  end

  def sync_errors_file_path
    "#{@playlist.name_path_ready}-errors.txt"
  end

  # --user-auth loest bei spotdl einen Browser-OAuth-Login gegen die eigene
  # Spotify-App aus, dessen fest einprogrammierte Redirect-URI (127.0.0.1:9900)
  # aktuell im Spotify-Dashboard nicht eingetragen werden kann ("not secure").
  # Fuer oeffentliche Playlists reicht die Client-Credentials-Flow (kein
  # Browser, kein Redirect noetig), daher nur bei privaten/unbekannten
  # Playlists anfordern.
  def user_auth_flag
    @playlist.public? ? '' : ' --user-auth'
  end

  def playlist_url
    @playlist.url || "https://open.spotify.com/playlist/#{@playlist.spotify_id}"
  end

  def save_file
    "#{@playlist.name_path_ready}.spotdl"
  end
end
