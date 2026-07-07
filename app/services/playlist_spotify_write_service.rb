# frozen_string_literal: true

# Verbindet einen Spotify-Schreib-Aufruf mit der lokalen Persistierung: pusht zuerst zu Spotify
# (nur wenn die Playlist eine spotify_id hat), uebernimmt danach die von Spotify zurueckgegebene
# snapshot_id lokal - beides unter demselben SYNC_LOCK wie der Pull-Sync (BuildMusicNetService),
# damit ein Push nie parallel zu einem laufenden Sync/Refresh laeuft. Ohne diesen Lock koennte
# sync_playlist_with_spotify eine noch nicht gepushte lokale Aenderung verwerfen, da es Spotify
# als alleinige Wahrheit behandelt. Schlaegt der Push fehl, bleibt der lokale Stand unveraendert.
# Lokale Playlists (spotify_id: nil) werden nur lokal geaendert, ohne Spotify-Aufruf und ohne
# Lock (der Pull-Sync fasst sie ohnehin nie an).
class PlaylistSpotifyWriteService
  def initialize(current_user)
    @gateway = SpotifyPlaylistsGateway.new(current_user)
  end

  def rename!(playlist, name)
    with_sync_lock(playlist) do
      snapshot_id = playlist.spotify_id.present? ? @gateway.rename_playlist(playlist, name) : nil

      ActiveRecord::Base.transaction(requires_new: true) do
        attrs = { name: name }
        attrs[:snapshot_id] = snapshot_id if snapshot_id
        playlist.update!(**attrs)
        playlist.library_ids = Library.matching(name).map(&:id)
      end
    end
  end

  def add_track!(playlist, track)
    with_sync_lock(playlist) do
      snapshot_id = playlist.spotify_id.present? ? @gateway.add_track(playlist, track) : nil

      ActiveRecord::Base.transaction(requires_new: true) do
        PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)
        playlist.update!(snapshot_id: snapshot_id) if snapshot_id
      end
    end
  end

  def remove_track!(playlist, track)
    with_sync_lock(playlist) do
      snapshot_id = playlist.spotify_id.present? ? @gateway.remove_track(playlist, track) : nil

      ActiveRecord::Base.transaction(requires_new: true) do
        playlist.playlist_tracks.find_by!(track: track).destroy!
        playlist.update!(snapshot_id: snapshot_id) if snapshot_id
      end
    end
  end

  private

  # Nur Spotify-verknuepfte Playlists brauchen den prozessweiten Lock - eine rein lokale
  # Aenderung kollidiert nie mit dem Pull-Sync (der sie nie anfasst).
  def with_sync_lock(playlist)
    return yield if playlist.spotify_id.blank?

    unless BuildMusicNetService::SYNC_LOCK.try_lock
      raise BuildMusicNetService::SyncAlreadyRunningError,
            "Es läuft bereits ein Sync - bitte warten, bis er fertig ist"
    end

    begin
      yield
    ensure
      BuildMusicNetService::SYNC_LOCK.unlock
    end
  end
end
