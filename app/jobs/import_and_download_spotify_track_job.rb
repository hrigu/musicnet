# frozen_string_literal: true

# Importiert einen Spotify-Track als eigenstaendigen lokalen Track und laedt ihn direkt herunter
# (Intent 88) - im Hintergrund, gleiches Async-Pattern wie DownloadMissingTracksJob (Intent 39),
# damit der Klick auf "Herunterladen" im Spotify-Tab den Request nicht blockiert. Meldet sich ueber
# denselben "downloads"-Turbo-Stream-Kanal zurueck wie der bestehende Playlist-Download.
class ImportAndDownloadSpotifyTrackJob < ApplicationJob
  def perform(spotify_track_id)
    track = ImportStandaloneSpotifyTrackService.import(spotify_track_id)
    success = DownloadStandaloneTrackService.new(track).download
    broadcast_progress(track, success)
  end

  private

  def broadcast_progress(track, success)
    Turbo::StreamsChannel.broadcast_append_to(
      "downloads", target: "download-log",
                   partial: "tracks/spotify_import_progress_entry", locals: { track: track, success: success }
    )
  end
end
