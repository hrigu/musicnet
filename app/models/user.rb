# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: %i[spotify]

  # Reiner Anzeige-Filter (Intent 57, ersetzt den festen Enum aus Intent 54) - schraenkt ein, was
  # auf Tracks/Playlists/Artists und in der Suche sichtbar ist. Bewusst getrennt von
  # SpotifyPlaylistsGateway#owned_library_playlist?, das weiterhin unveraendert bestimmt, was
  # ueberhaupt von Spotify importiert wird - ein Bibliotheks-Wechsel hier aendert nichts an der
  # lokalen DB oder am naechsten Sync. nil bedeutet "Alle" (kein Filter).
  belongs_to :active_library, class_name: "Library", optional: true
  has_many :dj_session_playbacks, dependent: :destroy
  has_many :tag_assignments, dependent: :destroy
  validate :active_library_must_exist_if_present

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

  # Optional ausblendbare Spalten der Tracks-/Playlist-Tabelle (Intent 80, siehe
  # Track::OPTIONAL_COLUMNS) - hidden_track_columns speichert nur die ausgeblendeten Keys, nicht
  # die sichtbaren, damit ein User ohne diese Einstellung (leeres Array, Migrations-Default)
  # weiterhin alle Spalten sieht wie vor Einfuehrung dieser Funktion.
  def column_visible?(key)
    hidden_track_columns.exclude?(key)
  end

  def spotify_avatar_url
    return if spotify_user_data.blank?

    JSON.parse(spotify_user_data).fetch("images", []).first&.fetch("url", nil)
  rescue JSON::ParserError, TypeError
    nil
  end

  private

  # belongs_to allein prueft nur, ob active_library_id gesetzt ist - nicht, ob es ueberhaupt eine
  # bestehende Library referenziert (nil bleibt weiterhin gueltig, bedeutet "Alle").
  def active_library_must_exist_if_present
    return if active_library_id.blank?

    errors.add(:active_library, "muss eine bestehende Bibliothek sein") unless Library.exists?(active_library_id)
  end
end
