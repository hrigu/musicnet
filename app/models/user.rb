# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: %i[spotify]

  # Reiner Anzeige-Filter (Intent 54) - schraenkt ein, was auf Tracks/Playlists/Artists und in
  # der Suche sichtbar ist. Bewusst getrennt von SpotifyPlaylistsGateway#owned_fusion_or_blues_playlist?,
  # das weiterhin unveraendert bestimmt, was ueberhaupt von Spotify importiert wird - ein
  # Kategorie-Wechsel hier aendert nichts an der lokalen DB oder am naechsten Sync.
  ACTIVE_PLAYLIST_CATEGORIES = %w[all blues fusion].freeze
  CATEGORY_NAME_SUBSTRINGS = { "blues" => "blues", "fusion" => "fusion" }.freeze

  validates :active_playlist_category, inclusion: { in: ACTIVE_PLAYLIST_CATEGORIES }

  # nil bedeutet "kein Filter" fuer die Track/Playlist/Artist-Scopes - gilt fuer "all" und,
  # als Soft-Failure, auch fuer einen unerwarteten/leeren Wert.
  def active_category_substring
    CATEGORY_NAME_SUBSTRINGS[active_playlist_category]
  end

  # spotify_user_data wird bei jedem Login aktualisiert, nicht nur bei der Erstellung -
  # sonst bleiben z.B. Avatar-URLs auf dem Stand des allerersten Logins und laufen ab.
  def self.from_omniauth(auth, spotify_user_data)
    user = where(provider: auth.provider, uid: auth.uid).first_or_initialize do |new_user|
      new_user.email = auth.info.email
      new_user.password = Devise.friendly_token[0, 20]
    end
    user.spotify_user_data = spotify_user_data
    user.save!
    user
  end

  def spotify_user
    @spotify_user ||= RSpotify::User.new(JSON.parse(spotify_user_data))
  end

  def spotify_avatar_url
    return if spotify_user_data.blank?

    JSON.parse(spotify_user_data).fetch("images", []).first&.fetch("url", nil)
  rescue JSON::ParserError, TypeError
    nil
  end
end
