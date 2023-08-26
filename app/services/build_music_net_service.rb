class BuildMusicNetService
  def initialize current_user
    @current_user = current_user
  end

  # Erstellt die ganze DB aus allen Playlists, die der Owner erstellt hat.
  def build
    spotify_playlists = fetch_all_playlists_from_spotify
    spotify_playlists.each do |spot_playlist|
      next if spot_playlist.owner.id != @current_user.spotify_user.id
      build_playlist(spot_playlist)
    end
  end



  private

  # Erstellt aus der spot_playlist, eine entsprechendes Playlist und speichert es in der DB
  # Für jeden spot_track wird dann ein Track erstellt
  def build_playlist(spot_playlist)
    Rails.logger.info "build_playlist: #{spot_playlist.name}"
    playlist = Playlist.find_by(spotify_id: spot_playlist.id)
    unless playlist.present?
      playlist = Playlist.create!(spotify_id: spot_playlist.id, snapshot_id: spot_playlist.snapshot_id, name: spot_playlist.name, public: spot_playlist.public)
    end

    spot_playlist.tracks.each do |spot_track|
      build_track(playlist, spot_playlist, spot_track)
    end
  end

  # Für jedes
  def build_track(playlist, spot_playlist, spot_track)
    Rails.logger.info " build_track: #{spot_track.name}"
    track = Track.find_by(spotify_id: spot_track.id)
    unless track.present?
      album = build_album(spot_track.album)
      artists = build_artists spot_track.artists

      popularity = try_fetch(spot_track, :popularity)
      audio_features = try_fetch(spot_track, :audio_features)
      #album
      track = Track.create!(
        spotify_id: spot_track.id,
        name: spot_track.name,
        url: spot_track.external_urls["spotify"],
        duration_ms: spot_track.duration_ms,
        popularity: popularity,
        audio_features: audio_features.to_json,
        album: album,
        artists: artists
      )
    end

    pt = PlaylistTrack.find_by(playlist: playlist, track: track)
    unless pt.present?
      pt = PlaylistTrack.create!(playlist: playlist, track: track, added_at: spot_playlist.tracks_added_at[spot_track.id].in_time_zone)
    end
  end

  def build_album spot_album
    Rails.logger.info "  build_album: #{spot_album.name}"
    album = Album.find_by(spotify_id: spot_album.id)

    unless album.present?
      artists = build_artists spot_album.artists
      popularity = try_fetch(spot_album, :popularity)#spot_album.popularity
      release_date = try_fetch(spot_album, :release_date)#spot_album.release_date
      album = Album.create!(spotify_id: spot_album.id, name: spot_album.name, release_date: release_date, popularity: popularity, url: spot_album.external_urls["spotify"], artists: artists)
    end
    album
  end

  def build_artists spot_artists
    artists = []
    spot_artists.each do |spot_artist|
      Rails.logger.info "   build_artists: #{spot_artist.name}"
      artist = Artist.find_by(spotify_id: spot_artist.id)
      unless artist.present?
        popularity = try_fetch(spot_artist, :popularity)
        artist = Artist.create!(spotify_id: spot_artist.id, name: spot_artist.name, popularity: popularity)
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
  end

  private
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
