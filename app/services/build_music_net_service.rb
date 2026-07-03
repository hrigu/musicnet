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
  end

  # Erstellt die ganze Modellstruktur aus allen Playlists, die der Owner erstellt hat.
  # Unveränderte Playlists (gleiche snapshot_id wie auf Spotify) werden komplett
  # übersprungen — kein Tracks-Fetch, keine DB-Mutation. Nur so bleibt der Sync bei
  # über 200 Playlists im Sekunden- statt Minutenbereich.
  def build
    with_sync_lock do
      own_spotify_user_id = @current_user.spotify_user.id
      own_playlists = fetch_all_playlists_from_spotify.select { |p| p.owner.id == own_spotify_user_id }

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
    spot_playlist = fetch_playlist_from_spotify(playlist.spotify_id)
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
    spot_tracks, added_at_by_track_id = fetch_all_tracks(spot_playlist)

    # Gleiche Atomaritäts-Garantie wie beim vollen Sync (siehe build_playlist)
    ActiveRecord::Base.transaction(requires_new: true) do
      removed_names = remove_vanished_tracks(playlist, spot_tracks.map(&:id))

      existing_spotify_ids = playlist.tracks.pluck(:spotify_id)
      new_spot_tracks = spot_tracks.reject { |t| existing_spotify_ids.include?(t.id) }
      new_spot_tracks.each { |t| build_track(playlist, t, added_at: added_at_by_track_id[t.id]) }

      playlist.update!(name: spot_playlist.name, snapshot_id: spot_playlist.snapshot_id)
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
    spot_tracks, added_at_by_track_id = fetch_all_tracks(spot_playlist)

    # Eine Transaktion pro Playlist statt pro Datensatz: schneller (ein Commit) und atomar.
    # requires_new erzwingt einen Savepoint auch innerhalb einer umgebenden Transaktion.
    ActiveRecord::Base.transaction(requires_new: true) do
      playlist = Playlist.find_or_create_by!(spotify_id: spot_playlist.id) do |p|
        @info.add_new_created_playlist(spot_playlist.name)
        p.snapshot_id = spot_playlist.snapshot_id
        p.name = spot_playlist.name
        p.public = spot_playlist.public
      end

      spot_tracks.each do |spot_track|
        build_track(playlist, spot_track, added_at: added_at_by_track_id[spot_track.id])
      end
    end
  end

  # Für jeden Spot_track in der spot_playlist wird, falls noch nicht vorhanden:
  # * ein Track und ein PlaylistTrack
  # * Ein Album
  # * Die Artisten
  # erstellt
  def build_track(playlist, spot_track, added_at:)
    Rails.logger.debug " build_track: #{spot_track.name}"

    track = Track.find_or_create_by!(spotify_id: spot_track.id) do |t|
      album = build_album(spot_track.album)
      artists = build_artists spot_track.artists
      popularity = try_fetch(spot_track, :popularity)
      audio_features = try_fetch(spot_track, :audio_features)
      @info.add_new_created_track(spot_track.name)
      t.name = spot_track.name
      t.url = spot_track.external_urls["spotify"]
      t.duration_ms = spot_track.duration_ms
      t.popularity = popularity
      t.audio_features = audio_features.to_json
      t.album = album
      t.artists = artists
      t.duration_ms = spot_track.duration_ms
    end

    PlaylistTrack.find_or_create_by!(playlist: playlist, track: track) do |pt|
      pt.added_at = added_at&.in_time_zone
    end
  end

  def build_album spot_album
    Rails.logger.debug "  build_album: #{spot_album.name}"
    Album.find_or_create_by!(spotify_id: spot_album.id) do |a|
      popularity = try_fetch(spot_album, :popularity) # spot_album.popularity
      release_date = try_fetch(spot_album, :release_date) # spot_album.release_date
      @info.add_new_created_album(spot_album.name)
      a.name = spot_album.name
      a.release_date = release_date
      a.popularity = popularity
      a.url = spot_album.external_urls["spotify"]
    end
  end

  def build_artists spot_artists
    artists = []
    spot_artists.each do |spot_artist|
      Rails.logger.debug "   build_artists: #{spot_artist.name}"
      artist = Artist.find_or_create_by!(spotify_id: spot_artist.id) do |a|
        @info.add_new_created_artist(spot_artist.name)
        a.name = spot_artist.name
        a.popularity = try_fetch(spot_artist, :popularity)
      end
      artists << artist
    end
    artists
  end

  # holt alle Playlists des SpotifyUsers mit dem Namen "fusion" oder "blues"
  def fetch_all_playlists_from_spotify
    playlists = []
    offset = 0
    limit = 50
    loop do
      new_playlists = @current_user.spotify_user.playlists(limit: limit, offset: offset) #=>
      break if new_playlists.empty?
      playlists << new_playlists
      offset += limit
    end
    playlists.flatten!
    playlists.select! do |p|
      name = p.name.downcase
      name.include?("fusion") || name.include?("blues")
    end
    Rails.logger.info("Anzahl Playlists: #{playlists.length}" )
    playlists
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

  # Sucht die Spotify-Playlist mit der spotify_id in den eigenen Playlists des Users
  def fetch_playlist_from_spotify(spotify_id)
    offset = 0
    limit = 50
    loop do
      page = @current_user.spotify_user.playlists(limit: limit, offset: offset)
      found = page.find { |p| p.id == spotify_id }
      return found if found
      return nil if page.size < limit

      offset += limit
    end
  end

  # Holt alle Tracks einer Spotify-Playlist über die 100er-Paginierung der API hinweg.
  # rspotify überschreibt tracks_added_at bei jedem Seitenabruf, deshalb wird pro Seite gemerged.
  def fetch_all_tracks(spot_playlist)
    tracks = []
    added_at_by_track_id = {}
    offset = 0
    limit = 100
    loop do
      page = spot_playlist.tracks(limit: limit, offset: offset)
      tracks.concat(page)
      added_at_by_track_id.merge!(spot_playlist.tracks_added_at || {})
      break if page.size < limit

      offset += limit
    end
    [tracks, added_at_by_track_id]
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

