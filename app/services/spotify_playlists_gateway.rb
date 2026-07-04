# frozen_string_literal: true

class SpotifyPlaylistsGateway
  def initialize(current_user)
    @spotify_user = current_user.spotify_user
  end

  def all
    fetch_pages(:playlists)
      .select { |playlist| owned_fusion_or_blues_playlist?(playlist) }
  end

  def find(spotify_id)
    fetch_pages(:playlists).find { |playlist| playlist.id == spotify_id }
  end

  # Spotify erlaubt beim Audio-Features-Endpoint maximal 100 Ids pro Request
  AUDIO_FEATURES_BATCH_SIZE = 100

  def audio_features_by_track_id(track_ids)
    fetch_in_slices(track_ids, AUDIO_FEATURES_BATCH_SIZE) { |slice| RSpotify::AudioFeatures.find(slice) }
  end

  # Spotify erlaubt beim Alben-Endpoint maximal 20 Ids pro Request
  ALBUMS_BATCH_SIZE = 20

  def albums_by_id(album_ids)
    fetch_in_slices(album_ids, ALBUMS_BATCH_SIZE) { |slice| RSpotify::Album.find(slice) }
  end

  # Spotify erlaubt beim Artists-Endpoint maximal 50 Ids pro Request
  ARTISTS_BATCH_SIZE = 50

  def artists_by_id(artist_ids)
    fetch_in_slices(artist_ids, ARTISTS_BATCH_SIZE) { |slice| RSpotify::Artist.find(slice) }
  end

  def tracks_for(spot_playlist)
    tracks = []
    added_at_by_track_id = {}
    offset = 0
    limit = 100

    loop do
      page = spot_playlist.tracks(limit: limit, offset: offset)
      break if page.empty?

      tracks.concat(page)
      added_at_by_track_id.merge!(spot_playlist.tracks_added_at || {})

      offset += limit
    end

    [tracks, added_at_by_track_id]
  end

  private

  # Anzahl Retries bei 429 (Rate Limit), bevor eine Slice endgültig aufgegeben wird
  MAX_RATE_LIMIT_RETRIES = 3

  # Obergrenze für die Wartezeit zwischen Retries - ein sehr hoher Retry-After-Header
  # von Spotify soll den (synchron laufenden) Sync nicht über Gebühr blockieren
  MAX_RETRY_WAIT_SECONDS = 30

  # Holt Objekte gebündelt in Slices und liefert sie als Hash nach spotify_id. Fehler pro
  # Slice werden nur geloggt (weiche Semantik wie try_fetch im Service): z. B. darf ein 403
  # des abgeschalteten Audio-Features-Endpoints den Import nicht stoppen. Ein 429 (Rate
  # Limit) wird dagegen mit Backoff retryt statt die Slice sofort verloren zu geben - sonst
  # schlägt bei einem vollen Sync mit vielen Playlists praktisch jeder Alben-/Artists-Batch
  # fehl, weil die Requests ohne Pause aufeinanderfolgen.
  def fetch_in_slices(ids, batch_size, &fetcher)
    ids.uniq.each_slice(batch_size).each_with_object({}) do |slice, result|
      objects = fetch_slice_with_retry(slice, &fetcher)
      objects.compact.each { |object| result[object.id] = object }
    end
  end

  def fetch_slice_with_retry(slice, attempt: 0, &fetcher)
    fetcher.call(slice)
  rescue RestClient::Exception => e
    return give_up_on_slice(slice, e) unless e.http_code == 429 && attempt < MAX_RATE_LIMIT_RETRIES

    wait_before_retry(slice, e, attempt)
    fetch_slice_with_retry(slice, attempt: attempt + 1, &fetcher)
  end

  def wait_before_retry(slice, exception, attempt)
    wait_seconds = [retry_after_seconds(exception) || 2**(attempt + 1), MAX_RETRY_WAIT_SECONDS].min
    Rails.logger.warn(
      "Spotify-Rate-Limit (429, #{slice.size} Ids) - warte #{wait_seconds}s " \
      "(Versuch #{attempt + 1}/#{MAX_RATE_LIMIT_RETRIES})"
    )
    sleep(wait_seconds)
  end

  def give_up_on_slice(slice, exception)
    Rails.logger.warn("Spotify-Batch-Lookup fehlgeschlagen (#{slice.size} Ids): #{exception.message}")
    []
  end

  def retry_after_seconds(exception)
    Integer(exception.http_headers&.[](:retry_after))
  rescue ArgumentError, TypeError
    nil
  end

  def fetch_pages(method_name)
    pages = []
    offset = 0
    limit = 50

    loop do
      page = @spotify_user.public_send(method_name, limit: limit, offset: offset)
      break if page.empty?

      pages.concat(page)

      offset += limit
    end

    pages
  end

  def owned_fusion_or_blues_playlist?(playlist)
    playlist.owner.id == @spotify_user.id && /fusion|blues/i.match?(playlist.name)
  end
end
