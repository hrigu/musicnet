class BuildMusicNetService
  def initialize current_user
    @current_user = current_user
  end

  # Erstellt die ganze Modellstruktur aus allen Playlists, die der Owner erstellt hat.
  def build
    PlaylistTrack.delete_all
    #Track.delete_all
    #Album.delete_all
    #Artist.delete_all

    spotify_playlists = fetch_all_playlists_from_spotify
    spotify_playlists.each do |spot_playlist|
      next if spot_playlist.owner.id != @current_user.spotify_user.id
      build_playlist(spot_playlist)
    end
  end

  private

  # Erstellt aus der spot_playlist eine entsprechendes Playlist und speichert es in der DB
  # Für jeden spot_track wird dann ein Track erstellt
  def build_playlist(spot_playlist)
    Rails.logger.info "build_playlist: #{spot_playlist.name}"
    playlist = Playlist.find_or_create_by!(spotify_id: spot_playlist.id) do |p|
      p.snapshot_id = spot_playlist.snapshot_id
      p.name = spot_playlist.name
      p.public = spot_playlist.public
    end

    spot_playlist.tracks.each do |spot_track|
      build_track(playlist, spot_playlist, spot_track)
    end
  end

  # Für jeden Spot_track in der spot_playlist wird, falls noch nicht vorhanden:
  # * ein Track und ein PlaylistTrack
  # * Ein Album
  # * Die Artisten
  # erstellt
  def build_track(playlist, spot_playlist, spot_track)
    Rails.logger.info " build_track: #{spot_track.name}"

    track = Track.find_or_create_by!(spotify_id: spot_track.id) do |t|
      album = build_album(spot_track.album)
      artists = build_artists spot_track.artists
      popularity = try_fetch(spot_track, :popularity)
      audio_features = try_fetch(spot_track, :audio_features)
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
      pt.added_at = spot_playlist.tracks_added_at[spot_track.id].in_time_zone
    end
  end

  def build_album spot_album
    Rails.logger.info "  build_album: #{spot_album.name}"
    Album.find_or_create_by!(spotify_id: spot_album.id) do |a|
      popularity = try_fetch(spot_album, :popularity) # spot_album.popularity
      release_date = try_fetch(spot_album, :release_date) # spot_album.release_date
      a.name = spot_album.name
      a.release_date = release_date
      a.popularity = popularity
      a.url = spot_album.external_urls["spotify"]
    end
  end

  def build_artists spot_artists
    artists = []
    spot_artists.each do |spot_artist|
      Rails.logger.info "   build_artists: #{spot_artist.name}"
      artist = Artist.find_or_create_by!(spotify_id: spot_artist.id) do |a|
        a.name = spot_artist.name
        a.popularity = try_fetch(spot_artist, :popularity)
      end
      artists << artist
    end
    artists
  end

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
      name.include?("fusion")
    end
    Rails.logger.info("Anzahl Playlists: #{playlists.length}" )
    playlists
  end

  def try_fetch(object, attribute)
    result = nil
    begin
      result = object.send(attribute)
    rescue => e
      Rails.logger.info(e.message)
    end
    result
  end

end
