# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: %i[spotify]

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
