# frozen_string_literal: true

# Prozessweite Merkliste "welche Spotify-Track-IDs sind gerade per ImportAndDownloadSpotifyTrackJob
# am Importieren/Herunterladen" (Intent 88 Nachtrag) - der Turbo-8-Spinner auf dem "Herunterladen"-
# Button (data-turbo-submits-with) verschwindet sofort wieder, sobald die Redirect-Antwort auf
# #import_from_spotify eintrifft: die neu geladene Seite rendert die Zeile ganz normal, der Job
# selbst laeuft ja noch im Hintergrund weiter. Ohne diese Merkliste faellt die Zeile fuer die
# gesamte Wartezeit auf den ganz normalen "Herunterladen"-Button zurueck, bis irgendwann der
# Turbo-Stream-Broadcast (siehe ImportAndDownloadSpotifyTrackJob#broadcast_row_update) die Zelle
# ersetzt - keine sichtbare Rueckmeldung dazwischen, genau der gemeldete Bug. Gleiches
# In-Process-Speicher-Muster wie DownloadPlaylistService::DOWNLOAD_LOCK statt einer DB-Spalte, da
# dieser Zustand rein transient ist und eine einzelne Rails-Instanz (Single-User-App) genuegt.
class PendingSpotifyImports
  IDS = Concurrent::Set.new

  def self.add(spotify_track_id)
    IDS.add(spotify_track_id)
  end

  def self.remove(spotify_track_id)
    IDS.delete(spotify_track_id)
  end

  def self.pending?(spotify_track_id)
    IDS.include?(spotify_track_id)
  end
end
