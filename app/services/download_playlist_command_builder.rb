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

  def initialize(playlist)
    @playlist = playlist
  end

  def build
    "spotdl sync #{playlist_url} --save-file #{save_file} --sync-without-deleting" \
      "#{user_auth_flag} --format m4a --audio #{AUDIO_PROVIDERS}"
  end

  private

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
