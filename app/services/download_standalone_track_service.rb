# frozen_string_literal: true

# Laedt genau einen Track per Spotify-URL herunter, ohne Playlist-Kontext (Intent 88) - fuer
# Tracks aus dem Spotify-"Zuletzt gespielt"-Tab, gerade frisch per
# ImportStandaloneSpotifyTrackService importiert. Spiegelt den "small batch"-Zweig von
# DownloadPlaylistCommandBuilder (gleiche Provider-Fallback-Kette, gleiche Flags), aber ohne
# dessen Playlist-/Missing-Tracks-Bezug - hier ist immer nur ein einzelner Track gemeint.
class DownloadStandaloneTrackService
  def initialize(track)
    @track = track
  end

  # Teilt sich den DOWNLOAD_LOCK mit DownloadPlaylistService (nicht einen eigenen Mutex), damit
  # nie zwei spotdl-Prozesse gleichzeitig laufen, egal ueber welchen Code-Pfad sie gestartet
  # wurden - genau das, was der Lock verhindern soll. Laeuft hier bereits im Hintergrund-Job
  # (Intent 39-Async-Pattern), darum blockierendes synchronize statt try_lock: warten, bis ein
  # anderer Download fertig ist, ist hier unproblematisch, es gibt keinen Request, der sonst haengt.
  def download
    DownloadPlaylistService::DOWNLOAD_LOCK.synchronize do
      tracks_dir = Rails.root.join(DownloadPlaylistService::TRACKS_DIR)
      command = "spotdl download #{track_url} --format m4a --audio #{DownloadPlaylistCommandBuilder::AUDIO_PROVIDERS} --simple-tui"
      result = system(command, chdir: tracks_dir)
      Rails.logger.info(result)
      next false unless result

      AudioFeaturesExtractionService.new([@track]).extract_missing
      Track.preload_track_paths([@track])
      @track.track_path.present?
    end
  end

  private

  def track_url
    @track.url || "https://open.spotify.com/track/#{@track.spotify_id}"
  end
end
