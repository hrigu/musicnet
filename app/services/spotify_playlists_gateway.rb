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
