# frozen_string_literal: true

# Importiert einen Spotify-Track als eigenstaendigen lokalen Track und laedt ihn direkt herunter
# (Intent 88) - im Hintergrund, gleiches Async-Pattern wie DownloadMissingTracksJob (Intent 39),
# damit der Klick auf "Herunterladen" im Spotify-Tab den Request nicht blockiert. Meldet sich ueber
# denselben "downloads"-Turbo-Stream-Kanal zurueck wie der bestehende Playlist-Download.
class ImportAndDownloadSpotifyTrackJob < ApplicationJob
  def perform(spotify_track_id)
    track = ImportStandaloneSpotifyTrackService.import(spotify_track_id)
    broadcast_progress(track, safely_download(track))
    broadcast_row_update(track)
  ensure
    # Im ensure statt erst nach dem letzten Broadcast: soll auch dann greifen, wenn der Import
    # selbst (noch vor jedem Broadcast) mit einer Exception scheitert - sonst bliebe die Zeile
    # dauerhaft auf dem Spinner haengen statt zum "Herunterladen"-Button zurueckzufallen.
    PendingSpotifyImports.remove(spotify_track_id)
  end

  private

  # Der :async-Adapter (kein Sidekiq/Solid Queue) loggt eine unbehandelte Exception nur, er zeigt
  # sie dem User nirgends an - ohne dieses Rescue wuerde ein echter Fehlschlag beim spotdl-Aufruf
  # (z.B. Netzwerkfehler, unerwartetes Kommando-Verhalten) den Broadcast nie erreichen, und der DJ
  # saehe trotz erfolgreichem Import (Track existiert bereits in der DB) ueberhaupt keine
  # Rueckmeldung - genau der reale Bug, der gemeldet wurde. Gleiches Soft-Failure-Prinzip wie
  # AudioFeaturesExtractor/LocationNameResolver: nie einen stillen Fehlschlag ohne Rueckmeldung.
  def safely_download(track)
    DownloadStandaloneTrackService.new(track).download
  rescue StandardError => e
    Rails.logger.warn("ImportAndDownloadSpotifyTrackJob: Download fuer Track##{track.id} fehlgeschlagen: #{e.message}")
    false
  end

  def broadcast_progress(track, success)
    Turbo::StreamsChannel.broadcast_append_to(
      "downloads", target: "download-log",
                   partial: "tracks/spotify_import_progress_entry", locals: { track: track, success: success }
    )
  end

  # Aktualisiert die "Zuletzt gespielt"-Zeile (Titel-Link + "in Musicnet"-Badge) live, unabhaengig
  # vom Download-Erfolg - der Import selbst ist bereits vorher gegluckt, sobald #perform hier
  # ankommt, und genau der (nicht der Download) entscheidet ueber "in Musicnet".
  def broadcast_row_update(track)
    Turbo::StreamsChannel.broadcast_replace_to(
      "downloads", target: "spotify_track_title_#{track.spotify_id}",
                   partial: "tracks/spotify_track_title", locals: { playback_name: track.name, local_track: track }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      "downloads", target: "spotify_track_status_#{track.spotify_id}",
                   partial: "tracks/spotify_track_status", locals: { spotify_track_id: track.spotify_id, local_track: track }
    )
  end
end
