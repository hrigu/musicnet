# frozen_string_literal: true

class User < ApplicationRecord
  has_many :api_tokens
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: %i[spotify]

  def self.from_omniauth(auth, spotify_user_data)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      user.spotify_user_data = spotify_user_data
      # user.name = auth.info.name # assuming the user model has a name
      # user.username = auth.info.nickname # assuming the user model has a username
      # user.image = auth.info.image # assuming the user model has an image
      # If you are using confirmable and the provider(s) you use validate emails,
      # uncomment the line below to skip the confirmation emails.
      # user.skip_confirmation!
      #
    end
  end

  def spotify_user
    @spotify_user ||= RSpotify::User.new(JSON.parse(spotify_user_data))
  end
end
