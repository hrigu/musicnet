# frozen_string_literal: true

class UsersController < ApplicationController
  skip_before_action :authenticate_user!

  # Wird aufgerufen wenn man sich bei Spotify eingeloggt hat.
  def spotify
    Rails.logger.info 'UsersController #spotify'

    spotify_user = RSpotify::User.new(request.env['omniauth.auth'])
    @user = User.from_omniauth(request.env['omniauth.auth'], spotify_user.to_json)

    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication # this will throw if @user is not activated
    else
      session['devise.spotify_data'] = request.env['omniauth.auth'].except('extra')
      redirect_to new_user_registration_url
    end
  end

  def failure
    Rails.logger.info 'UsersController#failure...'
  end
end
