class BuildMusicNetService
  # Wird geworfen, wenn die Playlist auf Spotify nicht mehr existiert oder entfolgt wurde
  PlaylistNotFoundError = Class.new(StandardError)

  # Wird geworfen, wenn bereits ein Sync läuft (SQLite erlaubt nur einen Schreiber;
  # parallele Syncs würden sich den Write-Lock streitig machen)
  SyncAlreadyRunningError = Class.new(StandardError)

  # Prozessweiter Lock über alle Sync-Arten (voller Sync und Einzel-Refresh)
  SYNC_LOCK = Mutex.new

  def initialize current_user
    @current_user = current_user
    @info = ServiceInfo.new
    @spotify_playlists_gateway = SpotifyPlaylistsGateway.new(current_user)
  end

  # Erstellt die ganze Modellstruktur aus allen Playlists, die der Owner erstellt hat.
  # Unveränderte Playlists (gleiche snapshot_id wie auf Spotify) werden komplett
  # übersprungen — kein Tracks-Fetch, keine DB-Mutation. Nur so bleibt der Sync bei
  # über 200 Playlists im Sekunden- statt Minutenbereich.
  def build
    with_sync_lock do
      own_playlists = @spotify_playlists_gateway.all

      own_playlists.each do |spot_playlist|
        local_playlist = Playlist.find_by(spotify_id: spot_playlist.id)
        if local_playlist.nil?
          build_playlist(spot_playlist)
        elsif local_playlist.snapshot_id != spot_playlist.snapshot_id
          sync_playlist_with_spotify(local_playlist, spot_playlist)
        end
      end

      delete_vanished_playlists(own_playlists.map(&:id))
      cleanup_orphan_records
      @info
    end
  end

  # Gleicht eine einzelne Playlist mit Spotify ab: neue Tracks werden angelegt,
  # entfernte aus der Playlist gelöst. Liefert die Namen der Änderungen zurück.
  def refresh_playlist(playlist)
    with_sync_lock do
      refresh_playlist_without_lock(playlist)
    end
  end

  private

  def refresh_playlist_without_lock(playlist)
    spot_playlist = @spotify_playlists_gateway.find(playlist.spotify_id)
    raise PlaylistNotFoundError, "Playlist '#{playlist.name}' wurde auf Spotify nicht gefunden" if spot_playlist.nil?

    ActiveRecord::Base.transaction(requires_new: true) do
      info = sync_playlist_with_spotify(playlist, spot_playlist)
      cleanup_orphan_records
      info
    end
  end

  # Gleicht die Tracks einer lokalen Playlist mit der Spotify-Playlist ab: verschwundene
  # werden gelöst, neue angelegt, Name und snapshot_id aktualisiert. Orphan-Cleanup ist
  # Sache des Aufrufers (der volle Sync räumt einmal am Schluss auf, nicht pro Playlist).
  def sync_playlist_with_spotify(playlist, spot_playlist)
    spot_tracks, added_at_by_track_id = @spotify_playlists_gateway.tracks_for(spot_playlist)
    prefetched = prefetch_details(spot_tracks)

    # Gleiche Atomaritäts-Garantie wie beim vollen Sync (siehe build_playlist)
    ActiveRecord::Base.transaction(requires_new: true) do
      removed_names = remove_vanished_tracks(playlist, spot_tracks.map(&:id))

      existing_spotify_ids = playlist.tracks.pluck(:spotify_id)
      new_spot_tracks = spot_tracks.reject { |t| existing_spotify_ids.include?(t.id) }
      new_spot_tracks.each do |t|
        build_track(playlist, t, added_at: added_at_by_track_id[t.id], prefetched: prefetched)
      end

      @info.add_renamed_playlist(playlist.name, spot_playlist.name) if playlist.name != spot_playlist.name
      playlist.update!(name: spot_playlist.name, snapshot_id: spot_playlist.snapshot_id)
      assign_libraries(playlist)
      RefreshInfo.new(new_spot_tracks.map(&:name), removed_names)
    end
  end

  # Verhindert parallele Sync-Läufe. try_lock statt lock, damit der zweite Aufruf sofort
  # mit einer verständlichen Meldung scheitert, statt auf den SQLite-Write-Lock zu warten.
  def with_sync_lock
    raise SyncAlreadyRunningError, "Es läuft bereits ein Sync - bitte warten, bis er fertig ist" unless SYNC_LOCK.try_lock

    begin
      yield
    ensure
      SYNC_LOCK.unlock
    end
  end

  # Erstellt aus der spot_playlist eine entsprechendes Playlist und speichert es in der DB
  # Für jeden spot_track wird dann ein Track erstellt
  def build_playlist(spot_playlist)
    Rails.logger.info "build_playlist: #{spot_playlist.name}"
    spot_tracks, added_at_by_track_id = @spotify_playlists_gateway.tracks_for(spot_playlist)
    prefetched = prefetch_details(spot_tracks)

    # Eine Transaktion pro Playlist statt pro Datensatz: schneller (ein Commit) und atomar.
    # requires_new erzwingt einen Savepoint auch innerhalb einer umgebenden Transaktion.
    ActiveRecord::Base.transaction(requires_new: true) do
      playlist = Playlist.find_or_create_by!(spotify_id: spot_playlist.id) do |p|
        @info.add_new_created_playlist(spot_playlist.name)
        p.snapshot_id = spot_playlist.snapshot_id
        p.name = spot_playlist.name
        p.public = spot_playlist.public
      end
      assign_libraries(playlist)

      spot_tracks.each do |spot_track|
        build_track(playlist, spot_track, added_at: added_at_by_track_id[spot_track.id], prefetched: prefetched)
      end
    end
  end

  # Ordnet die Playlist allen Libraries zu, deren Stichwort im aktuellen Namen vorkommt (Intent
  # 57) - eine Playlist kann mehreren Libraries gleichzeitig angehören. library_ids= gleicht die
  # n:m-Zeilen automatisch ab (fuegt neue hinzu, entfernt nicht mehr passende).
  def assign_libraries(playlist)
    playlist.library_ids = Library.matching(playlist.name).map(&:id)
  end

  # Alben und Artists der lokal noch nicht vorhandenen Tracks gebündelt vorladen: wenige
  # Batch-Requests statt einem Request pro Album/Artist - nur so bleibt der Erstimport im
  # Minuten- statt Stundenbereich (Intent 33). Nur neue Datensätze brauchen die Details,
  # weil find_or_create_by! bestehende Zeilen nicht aktualisiert. Tempo/Energy kommen seit
  # Intent 35 nicht mehr von hier, sondern lokal via Essentia nach dem Download.
  def prefetch_details(spot_tracks)
    new_spot_tracks = locally_missing_tracks(spot_tracks)

    Prefetched.new(
      @spotify_playlists_gateway.albums_by_id(missing_album_ids(new_spot_tracks)),
      @spotify_playlists_gateway.artists_by_id(missing_artist_ids(new_spot_tracks))
    )
  end

  def locally_missing_tracks(spot_tracks)
    existing_ids = Track.where(spotify_id: spot_tracks.map(&:id)).pluck(:spotify_id)
    spot_tracks.uniq(&:id).reject { |t| existing_ids.include?(t.id) }
  end

  def missing_album_ids(new_spot_tracks)
    ids = new_spot_tracks.map { |t| t.album.id }.uniq
    ids - Album.where(spotify_id: ids).pluck(:spotify_id)
  end

  def missing_artist_ids(new_spot_tracks)
    ids = new_spot_tracks.flat_map { |t| t.artists.map(&:id) }.uniq
    ids - Artist.where(spotify_id: ids).pluck(:spotify_id)
  end

  # Für jeden Spot_track in der spot_playlist wird, falls noch nicht vorhanden:
  # * ein Track und ein PlaylistTrack
  # * Ein Album
  # * Die Artisten
  # erstellt
  def build_track(playlist, spot_track, added_at:, prefetched:)
    Rails.logger.debug " build_track: #{spot_track.name}"

    track = Track.find_or_create_by!(spotify_id: spot_track.id) do |t|
      album = build_album(spot_track.album, prefetched.albums[spot_track.album.id])
      artists = build_artists(spot_track.artists, prefetched.artists)
      popularity = try_fetch(spot_track, :popularity)
      @info.add_new_created_track(spot_track.name)
      t.name = spot_track.name
      t.url = spot_track.external_urls["spotify"]
      t.duration_ms = spot_track.duration_ms
      t.popularity = popularity
      t.album = album
      t.artists = artists
    end

    PlaylistTrack.find_or_create_by!(playlist: playlist, track: track) do |pt|
      pt.added_at = added_at&.in_time_zone
    end
  end

  # full_album stammt aus dem Batch-Lookup: Das Album im Playlist-Payload ist nur ein
  # simplified Objekt ohne popularity/release_date - jeder Zugriff darauf würde via
  # RSpotifys method_missing einen einzelnen complete!-Request auslösen.
  def build_album(spot_album, full_album)
    Rails.logger.debug "  build_album: #{spot_album.name}"
    Album.find_or_create_by!(spotify_id: spot_album.id) do |a|
      @info.add_new_created_album(spot_album.name)
      a.name = spot_album.name
      a.release_date = full_album&.release_date
      a.popularity = full_album&.popularity
      a.url = spot_album.external_urls["spotify"]
    end
  end

  # full_artists_by_id stammt aus dem Batch-Lookup - gleiche Begründung wie bei build_album
  def build_artists(spot_artists, full_artists_by_id)
    spot_artists.map do |spot_artist|
      Rails.logger.debug "   build_artists: #{spot_artist.name}"
      Artist.find_or_create_by!(spotify_id: spot_artist.id) do |a|
        @info.add_new_created_artist(spot_artist.name)
        a.name = spot_artist.name
        a.popularity = full_artists_by_id[spot_artist.id]&.popularity
      end
    end
  end

  # Playlists löschen, die auf Spotify nicht mehr existieren oder entfolgt wurden
  def delete_vanished_playlists(spotify_ids)
    playlists_to_delete = Playlist.where.not(spotify_id: spotify_ids)
    @info.add playlists: { deleted: playlists_to_delete.map(&:name) } if playlists_to_delete.present?
    playlists_to_delete.destroy_all
  end

  # Löst Tracks aus der Playlist, die auf Spotify nicht mehr enthalten sind
  def remove_vanished_tracks(playlist, spotify_track_ids)
    vanished = playlist.playlist_tracks.joins(:track).where.not(tracks: { spotify_id: spotify_track_ids })
    names = vanished.map { |pt| pt.track.name }
    vanished.destroy_all
    names
  end

  # Tracks ohne Playlist sowie Artists/Alben ohne Tracks löschen
  def cleanup_orphan_records
    tracks_to_delete = Track.select("tracks.id", "tracks.name").left_joins(:playlists).where(playlists: { id: nil })
    @info.add tracks: { deleted: tracks_to_delete.map(&:name)} if tracks_to_delete.present?
    tracks_to_delete.destroy_all

    artists_to_delete = Artist.select("artists.id", "artists.name").left_joins(:tracks).where(tracks: { id: nil })
    @info.add artists: { deleted: artists_to_delete.map(&:name)} if artists_to_delete.present?
    artists_to_delete.destroy_all

    albums_to_delete = Album.select("albums.id", "albums.name").left_joins(:tracks).where(tracks: { id: nil })
    @info.add albums: { deleted: albums_to_delete.map(&:name)} if albums_to_delete.present?
    albums_to_delete.destroy_all
  end

  def try_fetch(object, attribute)
    result = nil
    begin
      result = object.send(attribute)
    rescue => e
      Rails.logger.debug(e.message)
    end
    result
  end


  # Ergebnis eines Einzel-Playlist-Refreshs: Namen der hinzugekommenen und entfernten Tracks
  RefreshInfo = Struct.new(:added, :removed)

  # Gebündelt vorgeladene Spotify-Details (je ein Hash spotify_id → Objekt), siehe prefetch_details
  Prefetched = Struct.new(:albums, :artists)

  class ServiceInfo
    attr_reader :hash
    def initialize
      @hash = {}
    end

    def add_new_created_playlist(name)
      add(playlists: {created: name})
    end

    def add_new_created_track(name)
      add(tracks: {created: name})
    end

    def add_new_created_album(name)
      add(albums: {created: name})
    end

    def add_new_created_artist(name)
      add(artists: {created: name})
    end

    def add_renamed_playlist(old_name, new_name)
      add(playlists: {renamed: [old_name, new_name]})
    end



    # what is a hash mit einem Eintrag {playlists: {created: "yz"})}
    def add what
      key = what.keys.first
      unless @hash.has_key? key
        @hash[key] = {}
      end
      hash_value = @hash[key]
      value = what[key] # ist ein hash

      value.each do |k, v|
        unless hash_value.has_key? k
          hash_value[k] = []
        end
        hash_value[k] << v
      end
    end

  end


end
