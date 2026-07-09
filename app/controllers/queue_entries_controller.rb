# frozen_string_literal: true

class QueueEntriesController < ApplicationController
  def create
    QueueEntry.create!(track_id: params[:track_id]) unless QueueEntry.full?
    broadcast_badge_update(params[:track_id])

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to tracks_path }
    end
  end

  def destroy
    entry = QueueEntry.find(params[:id])
    track_id = entry.track_id
    entry.destroy
    broadcast_badge_update(track_id)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to tracks_path }
    end
  end

  # Wird vom Player-JS aufgerufen, wenn der aktuelle Track endet oder der Player-Play-Button bei
  # leerem Player gedrueckt wird (Intent 41) - entnimmt den aeltesten Eintrag (FIFO) und liefert
  # dessen Abspiel-Infos, damit das JS den naechsten Track starten kann.
  def advance
    entry = QueueEntry.order(:created_at).first
    return head :no_content unless entry

    track = entry.track
    entry.destroy
    broadcast_removal(entry)
    broadcast_badge_update(track.id)

    render json: track_json(track)
  end

  # Erstellt eine lokale Playlist (spotify_id: nil) mit den aktuell gequeueten Tracks in
  # Queue-Reihenfolge - die Queue selbst bleibt danach unveraendert bestehen (bewusste
  # Entscheidung, siehe Intent 42).
  def save_as_playlist
    playlist = Playlist.create!(name: params[:name], spotify_id: nil)
    QueueEntry.order(:created_at).each do |entry|
      PlaylistTrack.create!(playlist: playlist, track: entry.track, added_at: Time.current)
    end

    redirect_to playlist_path(playlist)
  end

  private

  def broadcast_removal(entry)
    Turbo::StreamsChannel.broadcast_remove_to("queue", target: entry)
  end

  # Aktualisiert die "in Queue"-Markierung ueberall dort live, wo der Track gerade sichtbar ist
  # (jede Seite ist ueber layouts/_audio_player.html.erb auf den "queue"-Stream abonniert) - ohne
  # das musste man die Seite neu laden, um die Markierung zu sehen (Intent 42 Nachtrag).
  def broadcast_badge_update(track_id)
    track = Track.find(track_id)
    Turbo::StreamsChannel.broadcast_replace_to(
      "queue", target: ActionView::RecordIdentifier.dom_id(track, :audio_file),
               partial: "components/audio_file", locals: { track: track }
    )
  end

  # trackId (camelCase), nicht track_id: audio_player_controller.js#play destrukturiert
  # { url, name, trackId, artist } sowohl aus diesem JSON (Queue-Advance) als auch aus dem
  # CustomEvent-detail des direkten Play-Buttons (audio_trigger_controller.js, dort schon
  # camelCase) - ein snake_case Key hier liess trackId beim Queue-Weg silently undefined werden,
  # wodurch weder der Detailseiten-Link noch das Speichern in "Zuletzt gespielt" (Intent 87)
  # ausgeloest wurden, obwohl der direkte Play-Button-Weg beides korrekt tat.
  def track_json(track)
    {
      url: stream_track_path(track.id),
      name: track.name,
      trackId: track.id,
      artist: track.artists.first&.name,
      playlists: helpers.playlist_names_for(track)
    }
  end
end
