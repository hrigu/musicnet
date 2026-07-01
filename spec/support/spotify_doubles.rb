# frozen_string_literal: true

# Doubles für die externe Spotify-Web-API-Grenze (RSpotify), damit BuildMusicNetService
# ohne echte Spotify-Requests getestet werden kann.
module SpotifyDoubles
  def spotify_playlist(id:, name:, owner_id:, tracks: [], public: true, snapshot_id: "snap-#{id}")
    tracks_added_at = tracks.each_with_object({}) { |t, h| h[t.id] = Time.current }
    double("RSpotify::Playlist",
           id: id,
           name: name,
           snapshot_id: snapshot_id,
           public: public,
           owner: double("RSpotify::User", id: owner_id),
           tracks: tracks,
           tracks_added_at: tracks_added_at)
  end

  def spotify_track(id:, name:, album:, artists: [], popularity: 50, duration_ms: 200_000)
    double("RSpotify::Track",
           id: id,
           name: name,
           external_urls: { "spotify" => "https://open.spotify.com/track/#{id}" },
           duration_ms: duration_ms,
           popularity: popularity,
           audio_features: nil,
           album: album,
           artists: artists)
  end

  def spotify_album(id:, name:, popularity: 40, release_date: "2020-01-01")
    double("RSpotify::Album",
           id: id,
           name: name,
           popularity: popularity,
           release_date: release_date,
           external_urls: { "spotify" => "https://open.spotify.com/album/#{id}" })
  end

  def spotify_artist(id:, name:, popularity: 30)
    double("RSpotify::Artist", id: id, name: name, popularity: popularity)
  end
end

RSpec.configure do |config|
  config.include SpotifyDoubles
end
