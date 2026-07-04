# frozen_string_literal: true

# Laedt fehlende Audiodateien playlist-weise nach (siehe Intent 21, warum playlist-weise statt
# pro Track), im Hintergrund statt im Request-Zyklus (Intent 39). Ersetzt DownloadTrackService.
class DownloadMissingTracksJob < ApplicationJob
  def perform(tracks)
    affected_playlists(tracks).each do |playlist|
      result = DownloadPlaylistService.new(playlist).download
      broadcast_progress(playlist, result) if result
    end
    broadcast_done
  end

  private

  def affected_playlists(tracks)
    tracks.flat_map(&:playlists).uniq
  end

  def broadcast_progress(playlist, result)
    Turbo::StreamsChannel.broadcast_append_to(
      "downloads", target: "download-log", partial: "tracks/download_progress_entry",
                   locals: { playlist: playlist, result: result }
    )
  end

  def broadcast_done
    Turbo::StreamsChannel.broadcast_append_to("downloads", target: "download-log", html: "<div>Fertig.</div>")
  end
end
