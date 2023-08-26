class UsersController < ApplicationController
  skip_before_action :authenticate_user!


  # Wird aufgerufen wenn man sich bei Spotify eingeloggt hat.
  def spotify

    Rails.logger.info "UsersController #spotify"

    spotify_user = RSpotify::User.new(request.env['omniauth.auth'])
    @user = User.from_omniauth(request.env['omniauth.auth'], spotify_user.to_json)

    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication #this will throw if @user is not activated
      #set_flash_message(:notice, :success, kind: "Spotify") if is_navigational_format?
    else
      session["devise.spotify_data"] = request.env["omniauth.auth"].except("extra")
      redirect_to new_user_registration_url
    end


    #spotify_user2 = RSpotify::User.new(JSON.parse @user.omniauth_auth)
    #
    #spotify_user.recently_played
    #spotify_user2.recently_played

    # # Now you can access user's private data, create playlists and much more
    #
    # # Access private data
    # Rails.logger.info spotify_user.country #=> "US"
    # Rails.logger.info spotify_user.email   #=> "example@email.com"
    #
    # Create playlist in user's Spotify account
    # playlist = spotify_user.create_playlist!('my-awesome-playlist')

    # # Add tracks to a playlist in user's Spotify account
    # tracks = RSpotify::Track.search('Know')
    # playlist.add_tracks!(tracks)
    # playlist.tracks.first.name #=> "Somebody That I Used To Know"
    #
    # # Access and modify user's music library
    # spotify_user.save_tracks!(tracks)
    # spotify_user.saved_tracks.size #=> 20
    # spotify_user.remove_tracks!(tracks)
    #
    # albums = RSpotify::Album.search('launeddas')
    # spotify_user.save_albums!(albums)
    # spotify_user.saved_albums.size #=> 10
    # spotify_user.remove_albums!(albums)
    #
    # # Use Spotify Follow features
    # spotify_user.follow(playlist)
    # spotify_user.follows?(artists)
    # spotify_user.unfollow(users)
    #
    # # Get user's top played artists and tracks
    # spotify_user.top_artists #=> (Artist array)
    # spotify_user.top_tracks(time_range: 'short_term') #=> (Track array)
    #
    # # Check doc for more
  end

  def failure
    Rails.logger.info "UsersController#failure..."
  end
end
